import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

serve(async (req) => {
  try {
    const { order_id, triggered_by } = await req.json()
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

    // Get escrow record
    const { data: escrow } = await supabase
      .from('escrow_records')
      .select('*')
      .eq('order_id', order_id)
      .eq('status', 'held')
      .single()

    if (!escrow) {
      return new Response(
        JSON.stringify({ error: 'Escrow not found or already released' }),
        { status: 404, headers: { 'Content-Type': 'application/json' } }
      )
    }

    const sellerAmount = escrow.amount_ghs - escrow.platform_fee_ghs

    // Credit seller wallet
    const { data: sellerWallet } = await supabase
      .from('wallets')
      .select('id, balance_ghs, total_earned')
      .eq('user_id', escrow.seller_id)
      .single()

    if (!sellerWallet) throw new Error('Seller wallet not found')

    await supabase.from('wallets').update({
      balance_ghs: sellerWallet.balance_ghs + sellerAmount,
      total_earned: sellerWallet.total_earned + sellerAmount,
    }).eq('user_id', escrow.seller_id)

    // Deduct escrow from buyer wallet escrow balance
    const { data: buyerWallet } = await supabase
      .from('wallets')
      .select('id, escrow_balance, total_spent')
      .eq('user_id', escrow.buyer_id)
      .single()

    if (buyerWallet) {
      await supabase.from('wallets').update({
        escrow_balance: Math.max(0, buyerWallet.escrow_balance - escrow.amount_ghs),
        total_spent: buyerWallet.total_spent + escrow.amount_ghs,
      }).eq('user_id', escrow.buyer_id)
    }

    // Mark escrow released
    await supabase.from('escrow_records').update({
      status: 'released',
      released_at: new Date().toISOString(),
      release_triggered_by: triggered_by,
    }).eq('id', escrow.id)

    // Record transaction for seller
    await supabase.from('wallet_transactions').insert({
      wallet_id: sellerWallet.id,
      user_id: escrow.seller_id,
      type: 'credit',
      amount_ghs: sellerAmount,
      fee_ghs: escrow.platform_fee_ghs,
      reference_type: 'marketplace_escrow_release',
      reference_id: order_id,
      description: 'Escrow released — marketplace sale',
      status: 'completed',
    })

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
