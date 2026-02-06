// Production configuration - safe to commit (anon key is public)
window.LOCAL_CONFIG = {
    SUPABASE_URL: 'https://vpmuooztcqzrrfsvjzwl.supabase.co',
    SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwbXVvb3p0Y3F6cnJmc3ZqendsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg0MDU4NTIsImV4cCI6MjA4Mzk4MTg1Mn0.RsRMH02v6Tx_AqGywu2DPFbrycxDCZwd1rw2IABJgSY',
    VERCEL_API_URL: 'https://nrome.vercel.app',
    PAYSTACK_PUBLIC_KEY: 'pk_test_74336bdb2862bdcde9f71f4c2e3243fc3a2fedf6'
};

window.VERCEL_API_URL = window.LOCAL_CONFIG.VERCEL_API_URL;
window.CONFIG = window.LOCAL_CONFIG; // Make CONFIG available globally
console.log('✅ Configuration loaded');
