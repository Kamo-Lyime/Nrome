# Vercel Deployment Guide - Enable HuggingFace AI

This guide will help you deploy the API proxy to Vercel to enable HuggingFace API calls without CORS issues.

## Prerequisites

- Free Vercel account: https://vercel.com/signup
- Vercel CLI installed

## Step 1: Install Vercel CLI

```bash
npm install -g vercel
```

## Step 2: Login to Vercel

```bash
vercel login
```

## Step 3: Deploy to Vercel

From your project directory:

```bash
cd "c:\Users\Kamono\Desktop\Nromebasic"
vercel
```

Follow the prompts:
- Set up and deploy? **Y**
- Which scope? Select your account
- Link to existing project? **N**
- Project name? **nrome** (or your choice)
- Directory? **./** (just press Enter)
- Override settings? **N**

## Step 4: Add Environment Variable

After deployment:

1. Go to your Vercel dashboard: https://vercel.com/dashboard
2. Select your **nrome** project
3. Go to **Settings** → **Environment Variables**
4. Add new variable:
   - **Name:** `HUGGING_FACE_API_KEY`
   - **Value:** Your HuggingFace API token (starts with `hf_`)
   - **Environments:** Production, Preview, Development (select all)
5. Click **Save**

## Step 5: Redeploy

```bash
vercel --prod
```

## Step 6: Get Your Vercel URL

After deployment completes, you'll see:
```
✅  Production: https://nrome-xyz.vercel.app [copied to clipboard]
```

## Step 7: Configure GitHub Secrets

1. Go to: https://github.com/Kamo-Lyime/Nrome/settings/secrets/actions
2. Add new secret:
   - **Name:** `VERCEL_API_URL`
   - **Value:** Your Vercel URL (e.g., `https://nrome-xyz.vercel.app`)

## Step 8: Update Local Config (Optional)

Edit `config.local.js` and add your Vercel URL:

```javascript
window.LOCAL_CONFIG = {
    // ... existing config ...
    VERCEL_API_URL: 'https://nrome-xyz.vercel.app'
};
```

## Step 9: Trigger Deployment

Push any change to GitHub to redeploy with Vercel integration:

```bash
git commit --allow-empty -m "Enable Vercel API proxy"
git push
```

## Testing

Your HuggingFace AI will now work on GitHub Pages at:
https://kamo-lyime.github.io/Nrome/

The app will automatically use the Vercel proxy when `VERCEL_API_URL` is configured, bypassing CORS restrictions.

## Troubleshooting

**API still not working?**
1. Check Vercel deployment logs: `vercel logs`
2. Verify environment variable is set in Vercel dashboard
3. Test the API endpoint: `curl -X POST https://your-url.vercel.app/api/huggingface -H "Content-Type: application/json" -d '{"prompt":"Hello"}'`

**Local development?**
- Add `VERCEL_API_URL` to your `config.local.js`
- Or leave it empty to use the local AI fallback
