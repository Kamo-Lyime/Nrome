// Local development configuration
// Copy this file to config.local.js and add your actual keys
// config.local.js is gitignored for security

window.LOCAL_CONFIG = {
    SUPABASE_URL: 'https://vpmuooztcqzrrfsvjzwl.supabase.co',
    SUPABASE_ANON_KEY: 'your_supabase_anon_key_here',
    VERCEL_API_URL: 'https://nrome.vercel.app'
};

window.VERCEL_API_URL = window.LOCAL_CONFIG.VERCEL_API_URL;
