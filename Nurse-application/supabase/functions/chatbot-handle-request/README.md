# Chatbot Handle Request Edge Function

This Edge Function handles chatbot requests for leave, shift changes, and late notifications.

## Environment Variables

This function requires the following environment variables to be set in Supabase Dashboard:

- `SUPABASE_URL` - Your Supabase project URL (e.g., `https://xxx.supabase.co`)
- `SUPABASE_SERVICE_ROLE_KEY` - Your Supabase service role key
- `RESEND_API_KEY` - Your Resend API key for sending emails

## IDE Errors (Expected)

If you see TypeScript errors in your IDE about `Deno.env` or Deno imports, these are **IDE-only errors** and will **NOT affect runtime**. Supabase Edge Functions run on Deno, and these APIs are available at runtime.

### To Fix IDE Errors (Optional)

1. Install the Deno VS Code extension
2. The `.vscode/settings.json` file should enable Deno for this folder
3. Or simply ignore these errors - they won't affect deployment or runtime

## Deployment

```bash
supabase functions deploy chatbot-handle-request
```

Make sure to set the environment variables in Supabase Dashboard → Settings → Edge Functions → Secrets.
