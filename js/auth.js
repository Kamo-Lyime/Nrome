// Shared Supabase auth utilities
const SUPABASE_URL = 'your_supabase_url_here';
const SUPABASE_ANON_KEY = 'your_supabase_anon_key_here';

// Initialize a single shared client
const supabaseClient = window.supabaseClient || supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
window.supabaseClient = supabaseClient;

async function getSession() {
    const { data, error } = await supabaseClient.auth.getSession();
    if (error) {
        console.error('Auth session error:', error);
        return null;
    }
    return data.session || null;
}

async function requireAuth() {
    const session = await getSession();
    if (!session) {
        const next = encodeURIComponent(window.location.pathname + window.location.search + window.location.hash);
        window.location.replace(`index.html?redirect=${next}`);
        return null;
    }
    return session;
}

function redirectIfAuthenticated(targetPath = 'dashboard.html') {
    getSession().then(session => {
        if (session) {
            window.location.replace(targetPath);
        }
    });
}

function authStatusListener() {
    supabaseClient.auth.onAuthStateChange((_event, session) => {
        const signOutButtons = document.querySelectorAll('[data-auth="signout"]');
        signOutButtons.forEach(btn => {
            btn.disabled = !session;
        });

        if (!session && !window.location.pathname.endsWith('/index.html')) {
            window.location.replace('index.html');
        }
    });
}

async function handleSignOut() {
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

function initAuthUI() {
    authStatusListener();
    wireSignOutButtons();
    wireLoginForm();
    wireRegisterForm();
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
