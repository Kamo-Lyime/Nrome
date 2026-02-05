// Shared Supabase auth utilities
// Use local config if available (for development), otherwise use placeholders (for production/CI)
const SUPABASE_URL = window.LOCAL_CONFIG?.SUPABASE_URL || 'your_supabase_url_here';
const SUPABASE_ANON_KEY = window.LOCAL_CONFIG?.SUPABASE_ANON_KEY || 'your_supabase_anon_key_here';

// Initialize a single shared client with error handling
let supabaseClient = null;
try {
    if (typeof supabase === 'undefined') {
        console.warn('⚠️ Supabase library not loaded yet. Waiting for CDN...');
        window.supabaseClient = null;
    } else if (SUPABASE_URL && SUPABASE_URL.startsWith('http') && SUPABASE_ANON_KEY && SUPABASE_ANON_KEY !== 'your_supabase_anon_key_here') {
        supabaseClient = window.supabaseClient || supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
        window.supabaseClient = supabaseClient;
        console.log('✅ Supabase client initialized successfully');
    } else {
        console.warn('⚠️ Supabase config not available yet. Waiting for production config injection or local config.');
        window.supabaseClient = null;
    }
} catch (error) {
    console.error('❌ Supabase initialization failed:', error);
    supabaseClient = null;
    window.supabaseClient = null;
}

async function getSession() {
    if (!supabaseClient) {
        console.warn('⚠️ Supabase client not initialized');
        return null;
    }
    const { data, error } = await supabaseClient.auth.getSession();
    if (error) {
        console.error('Auth session error:', error);
        return null;
    }
    return data.session || null;
}

async function requireAuth() {
    if (!supabaseClient) {
        console.error('❌ Authentication unavailable - Supabase not initialized');
        alert('Authentication system is not available. Please refresh the page or check your connection.');
        return null;
    }
    const session = await getSession();
    if (!session) {
        const next = encodeURIComponent(window.location.pathname + window.location.search + window.location.hash);
        window.location.replace(`index.html?redirect=${next}`);
        return null;
    }
    return session;
}

function redirectIfAuthenticated(targetPath = 'dashboard.html') {
    if (!supabaseClient) {
        console.warn('⚠️ Cannot check authentication - Supabase not initialized');
        return;
    }
    getSession().then(session => {
        if (session) {
            window.location.replace(targetPath);
        }
    });
}

function authStatusListener() {
    if (!supabaseClient) {
        console.warn('⚠️ Auth status listener skipped - Supabase not initialized');
        return;
    }
    
    // Unsubscribe from previous listener if it exists
    if (authSubscription) {
        authSubscription.data?.subscription?.unsubscribe();
        authSubscription = null;
    }
    
    authSubscription = supabaseClient.auth.onAuthStateChange((_event, session) => {
        const signOutButtons = document.querySelectorAll('[data-auth="signout"]');
        signOutButtons.forEach(btn => {
            btn.disabled = !session;
        });

        // Allow access to registration and public pages without authentication
        const publicPages = ['/index.html', '/nurse.html', '/pharmacy-register.html', '/pharmacy-register-test.html', '/pharmacy-register-minimal.html'];
        const isPublicPage = publicPages.some(page => window.location.pathname.endsWith(page));
        
        if (!session && !isPublicPage) {
            window.location.replace('index.html');
        }
    });
}

// Store the auth state subscription to prevent multiple listeners
let authSubscription = null;

async function handleSignOut() {
    if (!supabaseClient) {
        console.warn('⚠️ Cannot sign out - Supabase not initialized');
        return;
    }
    await supabaseClient.auth.signOut();
}

function wireSignOutButtons() {
    document.querySelectorAll('[data-auth="signout"]').forEach(btn => {
        btn.addEventListener('click', async (e) => {
            e.preventDefault();
            await handleSignOut();
        });
    });
}

function wireLoginForm() {
    const form = document.getElementById('loginForm');
    if (!form) return;

    form.addEventListener('submit', async (e) => {
        e.preventDefault();
        const email = document.getElementById('loginEmail').value.trim();
        const password = document.getElementById('loginPassword').value;
        const feedback = document.getElementById('loginFeedback');
        feedback.textContent = '';
        
        if (!supabaseClient) {
            feedback.textContent = 'Authentication system is loading. Please wait and try again.';
            feedback.classList.add('text-warning');
            return;
        }

        const { error } = await supabaseClient.auth.signInWithPassword({ email, password });
        if (error) {
            feedback.textContent = error.message;
            feedback.classList.remove('text-success');
            feedback.classList.add('text-danger');
            return;
        }

        feedback.textContent = 'Logged in. Redirecting...';
        feedback.classList.remove('text-danger');
        feedback.classList.add('text-success');

        const params = new URLSearchParams(window.location.search);
        const redirectTo = params.get('redirect');
        setTimeout(() => {
            window.location.replace(redirectTo || 'dashboard.html');
        }, 400);
    });
}

function wireRegisterForm() {
    const form = document.getElementById('registerForm');
    if (!form) return;

    form.addEventListener('submit', async (e) => {
        e.preventDefault();
        const email = document.getElementById('registerEmail').value.trim();
        const password = document.getElementById('registerPassword').value;
        const fullName = document.getElementById('registerName').value.trim();
        const role = document.getElementById('registerRole').value;
        const feedback = document.getElementById('registerFeedback');
        feedback.textContent = '';
        
        if (!supabaseClient) {
            feedback.textContent = 'Authentication system is loading. Please wait and try again.';
            feedback.classList.add('text-warning');
            return;
        }

        const { error } = await supabaseClient.auth.signUp({
            email,
            password,
            options: {
                data: { full_name: fullName, role }
            }
        });

        if (error) {
            feedback.textContent = error.message;
            feedback.classList.remove('text-success');
            feedback.classList.add('text-danger');
            return;
        }

        feedback.textContent = 'Account created. Redirecting to dashboard...';
        feedback.classList.remove('text-danger');
        feedback.classList.add('text-success');
        setTimeout(() => {
            window.location.replace('dashboard.html');
        }, 500);
    });
}

// Track if initAuthUI has been called to prevent multiple initializations
let authUIInitialized = false;

function initAuthUI() {
    // Prevent multiple initializations
    if (authUIInitialized) {
        console.log('⚠️ Auth UI already initialized, skipping...');
        return;
    }
    
    authUIInitialized = true;
    authStatusListener();
    wireSignOutButtons();
    wireLoginForm();
    wireRegisterForm();
}

// Retry Supabase initialization after a delay (for production config injection)
function retrySupabaseInit() {
    if (!supabaseClient && window.LOCAL_CONFIG?.SUPABASE_URL) {
        console.log('🔄 Retrying Supabase initialization with loaded config...');
        try {
            if (typeof supabase === 'undefined') {
                console.warn('⚠️ Supabase library still not loaded. Skipping retry.');
                return;
            }
            
            const url = window.LOCAL_CONFIG.SUPABASE_URL;
            const key = window.LOCAL_CONFIG.SUPABASE_ANON_KEY;
            
            if (url && url.startsWith('http') && key && key !== 'your_supabase_anon_key_here') {
                supabaseClient = supabase.createClient(url, key);
                window.supabaseClient = supabaseClient;
                window.authHelpers.supabaseClient = supabaseClient;
                console.log('✅ Supabase client initialized successfully on retry');
                
                // Re-initialize auth UI now that we have Supabase
                initAuthUI();
            }
        } catch (error) {
            console.error('❌ Retry Supabase initialization failed:', error);
        }
    }
}

// Expose helpers globally for other modules
window.authHelpers = {
    getSession,
    requireAuth,
    redirectIfAuthenticated,
    supabaseClient
};

// Auto-wire when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initAuthUI);
} else {
    initAuthUI();
}

// Retry initialization after config might be loaded (for production builds)
setTimeout(retrySupabaseInit, 500);
setTimeout(retrySupabaseInit, 2000);
