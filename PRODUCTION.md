# 🚀 Production Deployment Guide

## 🔐 Environment Variables Setup

### For Vercel Deployment:
1. Go to your Vercel dashboard
2. Select your project → Settings → Environment Variables
3. Add each variable:
   ```
   HUGGING_FACE_API_KEY = hf_your_actual_token_here
   COHERE_API_KEY = your_actual_cohere_key
   ```

### For Netlify Deployment:
1. Go to Site settings → Environment variables
2. Add your API keys:
   ```
   HUGGING_FACE_API_KEY = hf_your_actual_token_here
   COHERE_API_KEY = your_actual_cohere_key
   ```

### For Traditional Hosting:
Create a `.env` file (copy from `.env.example`) and use a build process to inject variables.

## 🛠️ Build Configuration

### Using Vite (Recommended for production):
1. Install Vite: `npm install -g vite`
2. Create `vite.config.js`:
   ```javascript
   import { defineConfig } from 'vite'
   
   export default defineConfig({
     define: {
       'process.env.HUGGING_FACE_API_KEY': JSON.stringify(process.env.HUGGING_FACE_API_KEY),
       'process.env.COHERE_API_KEY': JSON.stringify(process.env.COHERE_API_KEY),
     },
     build: {
       outDir: 'dist',
       assetsDir: 'assets'
     }
   })
   ```
3. Build: `vite build`
4. Deploy the `dist` folder

### Using environment variable replacement:
For simple deployments, you can use build-time replacement:

```bash
# Replace placeholders with actual values during deployment
sed -i 's/hf_your_token_here/'$HUGGING_FACE_API_KEY'/g' nurse.html
sed -i 's/your_cohere_key_here/'$COHERE_API_KEY'/g' nurse.html
```

## 🔒 Security Best Practices

### ✅ DO:
- Store API keys as environment variables
- Use different keys for development and production
- Regularly rotate API keys
- Monitor API usage and costs
- Use HTTPS for all deployments

### ❌ DON'T:
- Commit `.env` files to version control
- Share API keys in public repositories
- Use production keys in development
- Store keys in client-side code (for server-side apps)

## 🌍 Deployment Platforms

### Vercel (Recommended):
```bash
npm install -g vercel
vercel --env HUGGING_FACE_API_KEY=hf_your_token
```

### Netlify:
```bash
npm install -g netlify-cli
netlify deploy --prod --env HUGGING_FACE_API_KEY=hf_your_token
```

### GitHub Pages:
Use GitHub Secrets for environment variables in GitHub Actions.

## ⚡ Quick Start:
1. Copy `.env.example` to `.env`
2. Add your actual API keys
3. Test locally
4. Deploy with environment variables configured
5. Verify all features work in production

Your Nrome platform will automatically detect and use available AI services!