import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const PLATFORM_FEE_PERCENT = 0.05

serve(async (req) => {
  try {
    const {
      consultation_id, client_id, expert_id,
      session_price_ghs, payment_method, paystack_ref
    } = await req.json()

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    const platformFee = session_price_ghs * PLATFORM_FEE_PERCENT
    const expertEarnings = session_price_ghs - platformFee

    if (payment_method === 'wallet') {
      // Debit client wallet
      const { data: clientWallet } = await supabase
        .from('wallets')
        .select('id, balance_ghs, total_spent')
        .eq('user_id', client_id)
        .single()

      if (!clientWallet) throw new Error('Client wallet not found')
      if (clientWallet.balance_ghs < session_price_ghs) {
        return new Response(
          JSON.stringify({ error: 'Insufficient wallet balance' }),
          { status: 400, headers: { 'Content-Type': 'application/json' } }
        )
      }

      // Debit client
      await supabase.from('wallets').update({
        balance_ghs: clientWallet.balance_ghs - session_price_ghs,
        total_spent: clientWallet.total_spent + session_price_ghs,
      }).eq('user_id', client_id)

      // Credit expert
      const { data: expertWallet } = await supabase
        .from('wallets')
        .select('id, balance_ghs, total_earned')
        .eq('user_id', expert_id)
        .single()

      if (expertWallet) {
        await supabase.from('wallets').update({
          balance_ghs: expertWallet.balance_ghs + expertEarnings,
          total_earned: expertWallet.total_earned + expertEarnings,
        }).eq('user_id', expert_id)

        // Record expert earning
        await supabase.from('wallet_transactions').insert({
          wallet_id: expertWallet.id,
          user_id: expert_id,
          type: 'credit',
          amount_ghs: expertEarnings,
          fee_ghs: platformFee,
          reference_type: 'consultation_payment',
          reference_id: consultation_id,
          description: `Consultation fee (after 5% platform cut)`,
          status: 'completed',
        })
      }

      // Record client payment
      await supabase.from('wallet_transactions').insert({
        wallet_id: clientWallet.id,
        user_id: client_id,
        type: 'debit',
        amount_ghs: session_price_ghs,
        fee_ghs: 0,
        reference_type: 'consultation_payment',
        reference_id: consultation_id,
        description: 'Consultation session fee',
        status: 'completed',
      })
    }

    // Update consultation to paid
    await supabase.from('consultations').update({
      payment_status: 'paid',
      platform_fee_ghs: platformFee,
      expert_earnings_ghs: expertEarnings,
      status: 'paid',
      paid_start_at: new Date().toISOString(),
      payment_method,
      paystack_ref: paystack_ref ?? null,
    }).eq('id', consultation_id)

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
