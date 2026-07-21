import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const PAYSTACK_SECRET = Deno.env.get('PAYSTACK_SECRET_KEY')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

serve(async (req) => {
  try {
    const { reference, user_id, amount_ghs, type } = await req.json()

    // Verify with Paystack
    const paystackRes = await fetch(
      `https://api.paystack.co/transaction/verify/${reference}`,
      { headers: { Authorization: `Bearer ${PAYSTACK_SECRET}` } }
    )
    const paystackData = await paystackRes.json()

    if (!paystackData.status || paystackData.data.status !== 'success') {
      return new Response(
        JSON.stringify({ error: 'Payment verification failed' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

    if (type === 'wallet_topup') {
      // Credit wallet
      const { data: wallet } = await supabase
        .from('wallets')
        .select('id, balance_ghs, total_earned')
        .eq('user_id', user_id)
        .single()

      if (!wallet) throw new Error('Wallet not found')

      await supabase.from('wallets').update({
        balance_ghs: wallet.balance_ghs + amount_ghs,
        total_earned: wallet.total_earned + amount_ghs,
      }).eq('user_id', user_id)

      // Record transaction
      await supabase.from('wallet_transactions').insert({
        wallet_id: wallet.id,
        user_id,
        type: 'credit',
        amount_ghs,
        fee_ghs: 0,
        reference_type: 'wallet_topup',
        description: 'Wallet top-up via Paystack',
        paystack_ref: reference,
        status: 'completed',
      })
    }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
