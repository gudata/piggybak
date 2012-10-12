module Piggybak
  class LineItem < ActiveRecord::Base
    belongs_to :order
    acts_as_changer
  
    validates_presence_of :price
    validates_presence_of :description
    validates_presence_of :quantity
    validates_numericality_of :quantity, :only_integer => true, :greater_than_or_equal_to => 0

    scope :sellables, where(:line_item_type => 'sellable')
    scope :taxes, where(:line_item_type => 'tax')
    scope :shipments, where(:line_item_type => 'shipment')
    scope :payments, where(:line_item_type => 'payment')

    after_create :decrease_inventory, :if => Proc.new { |line_item| line_item.line_item_type == 'sellable' && !line_item.sellable.unlimited_inventory }
    after_destroy :increase_inventory, :if => Proc.new { |line_item| line_item.line_item_type == 'sellable' && !line_item.sellable.unlimited_inventory }
    after_update :update_inventory, :if => Proc.new { |line_item| line_item.line_item_type == 'sellable' && !line_item.sellable.unlimited_inventory }

    attr_accessible :sellable_id, :price, :unit_price, :description, :quantity, :line_item_type,
                    :payment_attributes, :shipment_attributes

    has_one :payment
    accepts_nested_attributes_for :payment

    has_one :shipment
    accepts_nested_attributes_for :shipment

    belongs_to :sellable    

    after_initialize :initialize_line_item
    before_validation :preprocess

    def initialize_line_item
      self.quantity ||= 1
      self.price ||= 0
    end

    def preprocess
      Piggybak.config.line_item_types.each do |k, v|
        if v.has_key?(:nested_attrs) && k != self.line_item_type.to_sym
          self.send("#{k}=", nil) 
        end
      end

      method = "preprocess_#{self.line_item_type}"
      self.send(method) if self.respond_to?(method)
    end

    def preprocess_sellable
      sellable = Piggybak::Sellable.find(self.sellable_id)

      return if sellable.nil?

      self.description = sellable.description
      self.unit_price = sellable.price
      self.price = self.unit_price*self.quantity.to_i 
    end

    def preprocess_shipment
      if !self._destroy
        if (self.new_record? || self.shipment.status != 'shipped') && self.shipment && self.shipment.shipping_method
          calculator = self.shipment.shipping_method.klass.constantize
          self.price = calculator.rate(self.shipment.shipping_method, self)
          self.price = ((self.price*100).to_i).to_f/100
          self.description = self.shipment.shipping_method.description
        end
        if self.shipment.nil? || self.shipment.shipping_method.nil?
          self.price = 0.00
          self.description = "Shipping"
        end
      end
    end

    def preprocess_payment
      if self.new_record?
        self.payment.payment_method_id ||= Piggybak::PaymentMethod.find_by_active(true).id if self.payment
        self.description = "Payment"
        self.price = 0
      end
    end

    def postprocess_payment
      return true if !self.new_record?

      if self.payment.process(self.order)
        self.price = -1*self.order.total_due
        self.order.total_due = 0
        return true
      else
        return false
      end
    end

    def sellable_id_enum
      ::Piggybak::Sellable.all.collect { |s| ["#{s.description}: $#{s.price}", s.id ] }
    end

    def admin_label
      if self.line_item_type == 'sellable'
        "#{self.quantity} x #{self.description} ($#{sprintf("%.2f", self.unit_price)}): $#{sprintf("%.2f", self.price)}".gsub('"', '&quot;')
      else
        "#{self.description}: $#{sprintf("%.2f", self.price)}".gsub('"', '&quot;')
      end
    end

    def decrease_inventory
      self.sellable.update_inventory(-1 * self.quantity)
    end

    def increase_inventory
      self.sellable.update_inventory(self.quantity)
    end

    def update_inventory
      if self.sellable_id != self.sellable_id_was
        old_sellable = Sellable.find(self.sellable_id_was)
        old_sellable.update_inventory(self.quantity_was)
        self.sellable.update_inventory(-1*self.quantity)
      else
        quantity_diff = self.quantity_was - self.quantity
        self.sellable.update_inventory(quantity_diff)
      end
    end
  end
end
