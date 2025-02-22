module Pay
  module Stripe
    autoload :Billable, "pay/stripe/billable"
    autoload :Charge, "pay/stripe/charge"
    autoload :Subscription, "pay/stripe/subscription"
    autoload :Error, "pay/stripe/error"

    module Webhooks
      autoload :ChargeRefunded, "pay/stripe/webhooks/charge_refunded"
      autoload :ChargeSucceeded, "pay/stripe/webhooks/charge_succeeded"
      autoload :CustomerDeleted, "pay/stripe/webhooks/customer_deleted"
      autoload :CustomerUpdated, "pay/stripe/webhooks/customer_updated"
      autoload :PaymentActionRequired, "pay/stripe/webhooks/payment_action_required"
      autoload :PaymentIntentSucceeded, "pay/stripe/webhooks/payment_intent_succeeded"
      autoload :PaymentMethodUpdated, "pay/stripe/webhooks/payment_method_updated"
      autoload :SubscriptionCreated, "pay/stripe/webhooks/subscription_created"
      autoload :SubscriptionDeleted, "pay/stripe/webhooks/subscription_deleted"
      autoload :SubscriptionRenewing, "pay/stripe/webhooks/subscription_renewing"
      autoload :SubscriptionUpdated, "pay/stripe/webhooks/subscription_updated"
      autoload :SubscriptionPaid, "pay/stripe/webhooks/subscription_paid"
    end

    extend Env

    def self.setup
      ::Stripe.api_key = private_key
      ::Stripe.api_version = "2020-08-27"

      # Used by Stripe to identify Pay for support
      ::Stripe.set_app_info("PayRails", partner_id: "pp_partner_IqhY0UExnJYLxg", version: Pay::VERSION, url: "https://github.com/pay-rails/pay")

      configure_webhooks
    end

    def self.public_key
      find_value_by_name(:stripe, :public_key)
    end

    def self.private_key
      find_value_by_name(:stripe, :private_key)
    end

    def self.signing_secret
      find_value_by_name(:stripe, :signing_secret)
    end

    def self.configure_webhooks
      Pay::Webhooks.configure do |events|
        # Listen to the charge event to make sure we get non-subscription
        # purchases as well. Invoice is only for subscriptions and manual creation
        # so it does not include individual charges.
        events.subscribe "stripe.charge.succeeded", Pay::Stripe::Webhooks::ChargeSucceeded.new
        events.subscribe "stripe.charge.refunded", Pay::Stripe::Webhooks::ChargeRefunded.new

        events.subscribe "stripe.payment_intent.succeeded", Pay::Stripe::Webhooks::PaymentIntentSucceeded.new

        # Warn user of upcoming charges for their subscription. This is handy for
        # notifying annual users their subscription will renew shortly.
        # This probably should be ignored for monthly subscriptions.
        events.subscribe "stripe.invoice.upcoming", Pay::Stripe::Webhooks::SubscriptionRenewing.new

        # Payment action is required to process an invoice
        events.subscribe "stripe.invoice.payment_action_required", Pay::Stripe::Webhooks::PaymentActionRequired.new
        
        # Payment action for update subscription status
        # TODO: Create
        # events.subscribe "stripe.invoice.update", Pay::Stripe::Webhooks::SubscriptionPaid.new

        # Payment action for update subscription status
        # TODO: Create
        events.subscribe "stripe.invoice.paid", Pay::Stripe::Webhooks::SubscriptionPaid.new

        # If a subscription is manually created on Stripe, we want to sync
        events.subscribe "stripe.customer.subscription.created", Pay::Stripe::Webhooks::SubscriptionCreated.new

        # If the plan, quantity, or trial ending date is updated on Stripe, we want to sync
        events.subscribe "stripe.customer.subscription.updated", Pay::Stripe::Webhooks::SubscriptionUpdated.new

        # When a customers subscription is canceled, we want to update our records
        events.subscribe "stripe.customer.subscription.deleted", Pay::Stripe::Webhooks::SubscriptionDeleted.new

        # Monitor changes for customer's default card changing
        events.subscribe "stripe.customer.updated", Pay::Stripe::Webhooks::CustomerUpdated.new

        # If a customer was deleted in Stripe, their subscriptions should be cancelled
        events.subscribe "stripe.customer.deleted", Pay::Stripe::Webhooks::CustomerDeleted.new

        # If a customer's payment source was deleted in Stripe, we should update as well
        events.subscribe "stripe.payment_method.attached", Pay::Stripe::Webhooks::PaymentMethodUpdated.new
        events.subscribe "stripe.payment_method.updated", Pay::Stripe::Webhooks::PaymentMethodUpdated.new
        events.subscribe "stripe.payment_method.card_automatically_updated", Pay::Stripe::Webhooks::PaymentMethodUpdated.new
        events.subscribe "stripe.payment_method.detached", Pay::Stripe::Webhooks::PaymentMethodUpdated.new
      end
    end
  end
end
