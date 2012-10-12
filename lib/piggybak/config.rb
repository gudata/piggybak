module Piggybak
  module Config
    class << self
      attr_accessor :payment_calculators
      attr_accessor :shipping_calculators
      attr_accessor :tax_calculators
      attr_accessor :default_country
      attr_accessor :activemerchant_mode
      attr_accessor :email_sender
      attr_accessor :order_cc
      attr_accessor :logging
      attr_accessor :logging_file
      attr_accessor :whois_url
      attr_accessor :line_item_types

      def reset
        @email_sender = "support@piggybak.org"
        @order_cc = nil

        @payment_calculators = ["::Piggybak::PaymentCalculator::Fake",
                                "::Piggybak::PaymentCalculator::AuthorizeNet"]
        @shipping_calculators = ["::Piggybak::ShippingCalculator::FlatRate",
                                 "::Piggybak::ShippingCalculator::Free",
                                 "::Piggybak::ShippingCalculator::Range"]
        @tax_calculators = ["::Piggybak::TaxCalculator::Percent"]

        @line_item_types = {:sellable => { :visible => true, :reference_type => "Piggybak::Sellable", :fields => ["sellable", "quantity"] },
                            :payment => { :visible => true, :reference_type => "Piggybak::Payment", :fields => ["payment"] },
                            :shipment => { :visible => true, :reference_type => "Piggybak::Shipment", :fields => ["shipment"] },
                            :adjustment => { :visible => true, :fields => ["description", "price"] },
                            :tax => { :visible => false }}

        @default_country = "US"

        @activemerchant_mode = :production

        @logging = false
        @logging_file = "/log/orders.log"

        @whois_url = nil
      end
    end

    self.reset
  end
end
