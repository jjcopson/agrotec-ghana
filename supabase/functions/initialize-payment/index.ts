import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const PAYSTACK_SECRET = Deno.env.get('PAYSTACK_SECRET_KEY')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const {
      email,
      amount,          // in pesewas (GHS * 100)
      currency = 'GHS',
      reference,
      metadata = {},
      payment_method,  // 'card', 'momo', 'bank'
      momo_number,     // e.g. "0241234567"
      momo_network,    // 'mtn', 'vod', 'tgo'
    } = await req.json()

    const body: Record<string, unknown> = {
      email,
      amount,
      currency,
      reference,
      metadata,
      callback_url: `${SUPABASE_URL}/functions/v1/paystack-webhook`,
    }

    // For Mobile Money — trigger USSD prompt directly
    if (payment_method === 'momo' && momo_number && momo_network) {
      body.mobile_money = {
        phone: momo_number,
        provider: momo_network, // 'mtn', 'vod', 'tgo'
      }
    }

    // For card — use inline/popup
    if (payment_method === 'card') {
      body.channels = ['card']
    }

    // For bank transfer
    if (payment_method === 'bank') {
      body.channels = ['bank_transfer']
    }

    const response = await fetch('https://api.paystack.co/transaction/initialize', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${PAYSTACK_SECRET}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    })

    const data = await response.json()

    if (!data.status) {
      return new Response(
        JSON.stringify({ error: data.message }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({
        success: true,
        authorization_url: data.data.authorization_url,
        access_code: data.data.access_code,
        reference: data.data.reference,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
