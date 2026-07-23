import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { createHmac } from 'https://deno.land/std@0.177.0/node/crypto.ts'

const PAYSTACK_SECRET = Deno.env.get('PAYSTACK_SECRET_KEY')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

serve(async (req) => {
  try {
    const body = await req.text()
    const signature = req.headers.get('x-paystack-signature')

    // Verify webhook signature
    const hash = createHmac('sha512', PAYSTACK_SECRET)
      .update(body)
      .digest('hex')

    if (hash !== signature) {
      return new Response('Invalid signature', { status: 401 })
    }

    const event = JSON.parse(body)
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

    if (event.event === 'charge.success') {
      const data = event.data
      const reference = data.reference
      const amountGhs = data.amount / 100 // convert from pesewas
      const metadata = data.metadata || {}

      // Determine what this payment is for from metadata
      const paymentType = metadata.payment_type
      const userId = metadata.user_id

      if (paymentType === 'wallet_topup' && userId) {
        // Credit wallet
        const { data: wallet } = await supabase
          .from('wallets')
          .select('id, balance_ghs, total_earned')
          .eq('user_id', userId)
          .single()

        if (wallet) {
          await supabase.from('wallets').update({
            balance_ghs: wallet.balance_ghs + amountGhs,
            total_earned: wallet.total_earned + amountGhs,
          }).eq('user_id', userId)

          await supabase.from('wallet_transactions').insert({
            wallet_id: wallet.id,
            user_id: userId,
            type: 'credit',
            amount_ghs: amountGhs,
            fee_ghs: 0,
            reference_type: 'wallet_topup',
            description: `Wallet top-up via ${data.channel}`,
            paystack_ref: reference,
            status: 'completed',
          })

          // Send in-app notification
          await supabase.from('notifications').insert({
            user_id: userId,
            type: 'payment',
            title: 'Wallet Topped Up',
            body: `₵${amountGhs.toFixed(2)} has been added to your wallet.`,
          })
        }
      }

      if (paymentType === 'order_payment' && metadata.order_id) {
        // Process marketplace escrow
        await supabase.rpc('process_marketplace_order', {
          p_order_id: metadata.order_id,
          p_buyer_id: metadata.buyer_id,
          p_seller_id: metadata.seller_id,
          p_amount_ghs: amountGhs,
          p_platform_fee_ghs: amountGhs * 0.025,
        })

        // Update order with paystack ref
        await supabase.from('orders').update({
          status: 'paid',
          paystack_ref: reference,
          payment_method: data.channel,
        }).eq('id', metadata.order_id)
      }

      if (paymentType === 'consultation_payment' && metadata.consultation_id) {
        const platformFee = amountGhs * 0.05
        const expertEarnings = amountGhs - platformFee

        await supabase.from('consultations').update({
          payment_status: 'paid',
          paystack_ref: reference,
          payment_method: data.channel,
          paid_start_at: new Date().toISOString(),
          status: 'paid',
          platform_fee_ghs: platformFee,
          expert_earnings_ghs: expertEarnings,
        }).eq('id', metadata.consultation_id)

        // Credit expert wallet
        const { data: expertWallet } = await supabase
          .from('wallets')
          .select('id, balance_ghs, total_earned')
          .eq('user_id', metadata.expert_id)
          .single()

        if (expertWallet) {
          await supabase.from('wallets').update({
            balance_ghs: expertWallet.balance_ghs + expertEarnings,
            total_earned: expertWallet.total_earned + expertEarnings,
          }).eq('user_id', metadata.expert_id)
        }
      }
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error(err)
    return new Response(JSON.stringify({ error: err.message }), { status: 500 })
  }
})
