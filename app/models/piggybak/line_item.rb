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

    #after_create :decrease_inventory, :if => Proc.new { |line_item| line_item.line_item_type == 'sellable' && !line_item.reference.unlimited_inventory }
    #after_destroy :increase_inventory, :if => Proc.new { |line_item| line_item.line_item_type == 'sellable' && !line_item.reference.unlimited_inventory }
    #after_update :update_inventory, :if => Proc.new { |line_item| line_item.line_item_type == 'sellable' && !line_item.reference.unlimited_inventory }

    attr_accessible :sellable_id, :price, :unit_price, :description, :quantity,
                    :payments_attributes, :shipments_attributes

    belongs_to :reference, :polymorphic => true, :inverse_of => :line_item

    has_one :payment #, :conditions => "reference_type = 'payment'"
    accepts_nested_attributes_for :payment

    has_one :shipment #, :conditions => "reference_type = 'shipment'"
    accepts_nested_attributes_for :shipment
    
    has_one :sellable #, :conditions => "reference_type = 'sellable'"
    #accepts_nested_attributes_for :sellable

    before_validation :preprocess

    def preprocess
      method = "preprocess_#{self.line_item_type}"
      self.send(method) if self.respond_to?(method)

      Piggybak.config.line_item_types.each do |k, v|
        if v.has_key?(:reference_type)
          if k.to_s == self.line_item_type
            self.reference_type = v[:reference_type]
          else
            self.send("#{k}=", nil)
          end
        end
      end
    end

    def preprocess_sellable
      self.description = self.reference.description
      self.unit_price = self.reference.price
      self.price = self.unit_price*self.quantity.to_i 
    end

    def preprocess_shipment 
      if !self._destroy
        if (self.new_record? || self.shipment.status != 'shipped') && self.shipment.shipping_method
          calculator = self.shipment.shipping_method.klass.constantize
          self.price = calculator.rate(self.shipment.shipping_method, self)
          self.price = ((self.price*100).to_i).to_f/100
          self.description = self.shipment.shipping_method.description
          self.quantity = 1
        end
      end
    end

    def preprocess_payment
      self.description = "Payment" # TODO: Update with more description??
      self.quantity = 1
      self.price = 0
    end

    def postprocess_payment
      if self.payment.process(self.order)
        self.price = self.order.total_due
        self.order.total_due = 0
        return true
      else
        return false
      end
    end

    def admin_label
      if self.line_item_type == 'sellable'
        "#{self.quantity} x #{self.description} ($#{sprintf("%.2f", self.unit_price)}): $#{sprintf("%.2f", self.price)}"
      else
        "#{self.description}: $#{sprintf("%.2f", self.price)}"
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
