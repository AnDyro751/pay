module Pay
    module Stripe
      module Webhooks
        class SubscriptionPaid
          def call(event)
            object = event.data.object

            puts "SUBSCRIPTION PAID----------"
  
            # We may already have the subscription in the database, so we can update that record
            subscription = Pay.subscription_model.find_by(processor: :stripe, processor_id: object.subscription)
  
            puts "-------------SUBSCRIPTION ------#{subscription.nil?}----\n\n\n\n----#{object.subscription}"
            # Create the subscription in the database if we don't have it already
            if subscription.nil?
              # The customer should already be in the database
              owner = Pay.find_billable(processor: :stripe, processor_id: object.customer)
  
              if owner.nil?
                Rails.logger.error("[Pay] Unable to find Pay::Billable with processor: :stripe and processor_id: '#{object.customer}'. Searched these models: #{Pay.billable_models.join(", ")}")
                return
              end
  
              subscription = Pay.subscription_model.new(name: Pay.default_product_name, owner: owner, processor: :stripe, processor_id: object.subscription)
            end
  
            subscription.status = object.status === "paid" ? "active" : "incomplete"
            return unless object.lines
            return if object.lines.data.length <= 0
            subscription.processor_plan = object.lines.data[0].plan.id
  
            subscription.save!
          end
        end
      end
    end
  end
  