module Piggybak
  class LineItem < ActiveRecord::Base
    belongs_to :order
    acts_as_changer
  
    validates_presence_of :price
    validates_presence_of :description
    validates_presence_of :quantity
    validates_numericality_of :quantity, :only_integer => true, :greater_than_or_equal_to => 0

    scope :sellables, where(:reference_type => 'Piggybak::Sellable')

    after_create :decrease_inventory, :if => Proc.new { |line_item| line_item.reference_type == 'Sellable' && !line_item.sellable.unlimited_inventory }
    after_destroy :increase_inventory, :if => Proc.new { |line_item| line_item.reference_type == 'Sellable' && !line_item.sellable.unlimited_inventory }
    after_update :update_inventory, :if => Proc.new { |line_item| line_item.reference_type == 'Sellable' && !line_item.sellable.unlimited_inventory }
    
    attr_accessible :sellable_id, :price, :unit_price, :description, :quantity

    has_one :payment, :conditions => "reference_type = 'Piggybak::Payment'"
    accepts_nested_attributes_for :payment

    has_one :shipment, :conditions => "reference_type = 'Piggybak::Shipment'"
    accepts_nested_attributes_for :shipment

    has_one :adjustment, :conditions => "reference_type = 'Piggybak::Adjustment'"
    accepts_nested_attributes_for :adjustment

    before_validation :clear_nonreferenced
    def clear_nonreferenced
      Piggybak.config.line_item_types.each do |klass|
        if self.reference_type != klass
          self.send(klass.demodulize.downcase + "=", nil)
        end
      end
      true 
    end

    def variant_id
      self.sellable_id
    end
    
    def variant_id=(value)
      self.sellable_id = value
    end
    
    def admin_label
      "#{self.quantity} x #{self.sellable.description}"
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
