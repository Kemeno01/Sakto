// Supabase Edge Function: scan-receipt
// Proxies receipt image OCR through Gemini so GEMINI_API_KEY is never shipped inside the mobile APK.
//
// Deploy:
//   supabase secrets set GEMINI_API_KEY="your-gemini-key"
//   supabase functions deploy scan-receipt

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const PROMPT = `Extract every purchased item, discount, and extra fee/tax from this receipt image and return ONLY valid JSON in this exact format:
{
  "store": "Short store or restaurant name (optional, max 20 chars)",
  "discount": 0.0,
  "fee": 0.0,
  "items": [
    {"name": "Item name", "price": 100.0, "qty": 1}
  ]
}
Rules:
- "price" MUST be the UNIT price of 1 item as a positive number (e.g. if 2x Sisig costs 230.00 total, set "qty": 2 and "price": 115.0).
- "qty" must be a positive integer (default 1).
- "discount": total discount amount as a positive number (e.g. if receipt shows Discount -110.00, set "discount": 110.0). Use 0 if none.
- "fee": total extra charges added ON TOP of item prices (e.g. Service Charge, Delivery Fee, Packaging Fee, or extra tax added after Subtotal). Do NOT include VAT if it is already included in the item prices (such as Vatable Sale + VAT 12% breakdown). Use 0 if none.
- Ignore subtotals, cash tendered, change, and grand total lines in "items".
- Keep item names clean and readable.
- If no items are readable, return {"store": "", "discount": 0, "fee": 0, "items": []}.`;

const MODELS = [
  "gemini-3.5-flash-lite",
  "gemini-3.5-flash",
  "gemini-flash-lite-latest",
  "gemini-2.5-flash-lite",
];

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const apiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
  if (!apiKey) {
    return new Response(JSON.stringify({ error: "Server GEMINI_API_KEY secret is not configured." }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const payload = await req.json();
    const imageBase64 = typeof payload?.imageBase64 === "string" ? payload.imageBase64 : "";
    const mimeType = typeof payload?.mimeType === "string" && payload.mimeType.startsWith("image/")
      ? payload.mimeType
      : "image/jpeg";

    if (!imageBase64 || imageBase64.length > 10_000_000) {
      return new Response(JSON.stringify({ error: "Invalid or oversized image payload." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = JSON.stringify({
      contents: [
        {
          parts: [
            { text: PROMPT },
            { inline_data: { mime_type: mimeType, data: imageBase64 } },
          ],
        },
      ],
      generationConfig: { responseMimeType: "application/json", temperature: 0.1 },
    });

    let lastStatus = 502;
    let lastErr = "AI request failed";

    for (const model of MODELS) {
      const res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": apiKey,
          },
          body,
        },
      );
      lastStatus = res.status;
      if (res.ok) {
        const decoded = await res.json();
        const parts = decoded?.candidates?.[0]?.content?.parts ?? [];
        const textPart = parts.find(
          (p: Record<string, unknown>) => p?.thought !== true && typeof p?.text === "string" && (p.text as string).trim().length > 0,
        );
        const rawText = (textPart?.text as string | undefined)?.trim() ?? "";
        let cleaned = rawText.replace(/^```(?:json)?\s*|\s*```$/g, "").trim();
        const start = cleaned.indexOf("{");
        const end = cleaned.lastIndexOf("}");
        if (start >= 0 && end > start) cleaned = cleaned.slice(start, end + 1);
        const parsed = JSON.parse(cleaned);
        return new Response(JSON.stringify(parsed), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      try {
        const errJson = await res.json();
        lastErr = errJson?.error?.message ?? `AI error (${res.status})`;
      } catch {
        lastErr = `AI error (${res.status})`;
      }
      if (![404, 429, 503].includes(res.status)) break;
    }

    return new Response(JSON.stringify({ error: lastErr }), {
      status: lastStatus,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e instanceof Error ? e.message : "Failed to analyze receipt" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
