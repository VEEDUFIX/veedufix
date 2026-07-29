import { GoogleGenerativeAI } from "@google/generative-ai";

export class AiService {
  async chat(message: string, chatHistory: { role: string; parts: { text: string }[] }[] = []): Promise<string> {
    const apiKey = process.env.GEMINI_API_KEY;

    if (!apiKey) {
      return "I'm currently running in offline mode because my API key hasn't been set up yet. Please ask the developer to add GEMINI_API_KEY to the backend .env file!";
    }

    try {
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

      const chat = model.startChat({
        history: chatHistory,
        generationConfig: {
          maxOutputTokens: 250,
          temperature: 0.7,
        },
      });

      const systemPrompt = `You are Veedufix AI, a helpful, friendly, and concise assistant for a home services marketplace app in Chennai, India.
Your job is to help customers find services (like AC repair, Plumbing, Cleaning, Electrician) and answer general questions about the app.
Keep responses under 3 sentences. Be extremely polite. Suggest booking a professional on the app.`;

      const result = await chat.sendMessage(`${systemPrompt}\n\nCustomer: ${message}`);
      return result.response.text();
    } catch (error: any) {
      console.error("AI Error:", error);
      return "Sorry, I'm having trouble connecting to my brain right now. Please try again later!";
    }
  }
}

export const aiService = new AiService();
