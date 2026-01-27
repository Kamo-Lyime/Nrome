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

    // Use OpenAI-compatible format since HuggingFace deprecated old inference API
    // We'll use a simple completion approach
    const response = await fetch('https://api-inference.huggingface.co/models/facebook/opt-350m', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.HUGGING_FACE_API_KEY}`,
      },
      body: JSON.stringify(prompt),
    });

    const data = await response.json();
    
    if (!response.ok) {
      console.error('HuggingFace error:', data);
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
