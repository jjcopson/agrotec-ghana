import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
// Arkesel or Paystack transfer key for MoMo payouts
const PAYSTACK_SECRET = Deno.env.get('PAYSTACK_SECRET_KEY')!

serve(async (req) => {
  try {
    const { user_id, amount_ghs, momo_number, momo_network } = await req.json()
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

    // Check balance
    const { data: wallet } = await supabase
      .from('wallets')
      .select('id, balance_ghs')
      .eq('user_id', user_id)
      .single()

    if (!wallet) throw new Error('Wallet not found')
    if (wallet.balance_ghs < amount_ghs) {
      return new Response(
        JSON.stringify({ error: 'Insufficient balance' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Map network to Paystack recipient type
    const networkMap: Record<string, string> = {
      'MTN': 'mtn',
      'Vodafone': 'vod',
      'AirtelTigo': 'tgo',
    }

    // Create Paystack transfer recipient
    const recipientRes = await fetch('https://api.paystack.co/transferrecipient', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${PAYSTACK_SECRET}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        type: 'mobile_money',
        name: `Withdrawal-${user_id}`,
        account_number: momo_number,
        bank_code: networkMap[momo_network] ?? 'mtn',
        currency: 'GHS',
      }),
    })
    const recipientData = await recipientRes.json()
    if (!recipientData.status) throw new Error('Failed to create transfer recipient')

    // Initiate transfer
    const transferRes = await fetch('https://api.paystack.co/transfer', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${PAYSTACK_SECRET}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        source: 'balance',
        amount: Math.round(amount_ghs * 100), // kobo/pesewas
        recipient: recipientData.data.recipient_code,
        reason: 'Agrotech Ghana wallet withdrawal',
        currency: 'GHS',
      }),
    })
    const transferData = await transferRes.json()
    if (!transferData.status) throw new Error('Transfer initiation failed')

    // Deduct from wallet
    await supabase.from('wallets').update({
      balance_ghs: wallet.balance_ghs - amount_ghs,
    }).eq('user_id', user_id)

    // Record transaction
    await supabase.from('wallet_transactions').insert({
      wallet_id: wallet.id,
      user_id,
      type: 'debit',
      amount_ghs,
      fee_ghs: 0,
      reference_type: 'withdrawal',
      description: `Withdrawal to ${momo_network} ${momo_number}`,
      status: 'completed',
      metadata: { transfer_code: transferData.data?.transfer_code },
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
