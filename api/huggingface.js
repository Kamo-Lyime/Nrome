export default async function handler(req, res) {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Credentials', true);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
  res.setHeader('Access-Control-Allow-Headers', 'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { prompt, max_tokens = 150 } = req.body;
    
    if (!prompt) {
      return res.status(400).json({ error: 'Prompt is required' });
    }

    // Use HuggingFace Serverless Inference API (new endpoint)
    const API_URL = 'https://api-inference.huggingface.co/models/microsoft/DialoGPT-medium';
    
    const response = await fetch(API_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.HUGGING_FACE_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ 
        inputs: prompt,
        parameters: {
          max_length: max_tokens,
          temperature: 0.7
        },
        options: {
          wait_for_model: true,
          use_cache: false
        }
      }),
    });

    const data = await response.json();
    
    if (!response.ok) {
      console.error('HuggingFace error:', response.status, data);
      return res.status(response.status).json({ 
        error: data.error || `HuggingFace API error: ${response.status}`,
        details: data
      });
    }
    
    return res.status(200).json(data);
  } catch (error) {
    console.error('HuggingFace API Error:', error);
    return res.status(500).json({ error: error.message || 'Failed to get AI response' });
  }
}
