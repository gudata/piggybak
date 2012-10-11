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

    after_create :decrease_inventory, :if => Proc.new { |line_item| line_item.line_item_type == 'sellable' && !line_item.reference.unlimited_inventory }
    after_destroy :increase_inventory, :if => Proc.new { |line_item| line_item.line_item_type == 'sellable' && !line_item.reference.unlimited_inventory }
    after_update :update_inventory, :if => Proc.new { |line_item| line_item.line_item_type == 'sellable' && !line_item.reference.unlimited_inventory }

    attr_accessible :sellable_id, :price, :unit_price, :description, :quantity,
                    :payments_attributes, :shipments_attributes

    belongs_to :reference, :polymorphic => true, :inverse_of => :line_item

    has_one :payment #, :conditions => "reference_type = 'payment'"
    accepts_nested_attributes_for :payment

    has_one :shipment #, :conditions => "reference_type = 'shipment'"
    accepts_nested_attributes_for :shipment
    
    has_one :sellable #, :conditions => "reference_type = 'sellable'"

    attr_accessor :sellable_select

    before_validation :preprocess
    after_initialize :initialize_line_item
    after_save :clean_reference

    def initialize_line_item
      method = "initialize_#{self.line_item_type}"
      self.send(method) if self.respond_to?(method)
    end

    def initialize_sellable
      if !self.new_record?
        self.sellable_select = self.reference_id
      end
    end

    def clean_reference
      if self.line_item_type == "payment" && self.payment && self.reference_id.nil?
        self.update_attribute(:reference_id, self.payment.id)
      end
    end

    def preprocess
      Piggybak.config.line_item_types.each do |k, v|
        if v.has_key?(:reference_type)
          if k == self.line_item_type.to_sym
            self.reference_type = v[:reference_type]
          else
            self.send("#{k}=", nil) #if k != :sellable
          end
        end
      end

      method = "preprocess_#{self.line_item_type}"
      self.send(method) if self.respond_to?(method)
    end

    def preprocess_sellable
      self.reference_id = self.sellable_select if self.sellable_select
      return if self.reference.nil?
      # Add error on sellable?

      self.description = self.reference.description
      self.unit_price = self.reference.price
      self.price = self.unit_price*self.quantity.to_i 
    end

    def preprocess_shipment
      if !self._destroy
        if (self.new_record? || self.shipment.status != 'shipped') && self.shipment && self.shipment.shipping_method
          calculator = self.shipment.shipping_method.klass.constantize
          self.price = calculator.rate(self.shipment.shipping_method, self)
          self.price = ((self.price*100).to_i).to_f/100
          self.description = self.shipment.shipping_method.description
          self.quantity = 1
        end
        if self.shipment.nil? || self.shipment.shipping_method.nil?
          self.price = 0.00
          self.quantity = 1
          self.description = "Shipping"
        end
      end
    end

    def preprocess_payment
      if self.new_record?
        self.payment.payment_method_id ||= Piggybak::PaymentMethod.find_by_active(true).id if self.payment
        self.description = "Payment"
        self.quantity = 1
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

    def sellable_select_enum
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
      self.reference.update_inventory(-1 * self.quantity)
    end

    def increase_inventory
      self.reference.update_inventory(self.quantity)
    end

    def update_inventory
      if self.reference_id != self.reference_id_was
        old_sellable = Sellable.find(self.reference_id_was)
        old_sellable.update_inventory(self.quantity_was)
        self.reference.update_inventory(-1*self.quantity)
      else
        quantity_diff = self.quantity_was - self.quantity
        self.reference.update_inventory(quantity_diff)
      end
    end
  end
end
