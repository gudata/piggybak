module Piggybak
  class LineItem < ActiveRecord::Base
    belongs_to :order
    acts_as_changer
    belongs_to :sellable
    alias :variant :sellable
  
    validates_presence_of :price
    validates_presence_of :description
    validates_presence_of :quantity
    validates_numericality_of :quantity, :only_integer => true, :greater_than_or_equal_to => 0

    scope :sellables, where(:reference_type => 'Variant')
    belongs_to :reference, :polymorphic => true, :inverse_of => :line_item
    attr_accessible :reference_id, :reference_type

    after_create :decrease_inventory, :if => Proc.new { |line_item| line_item.reference_type == 'Sellable' && !line_item.sellable.unlimited_inventory }
    after_destroy :increase_inventory, :if => Proc.new { |line_item| line_item.reference_type == 'Sellable' && !line_item.sellable.unlimited_inventory }
    after_update :update_inventory, :if => Proc.new { |line_item| line_item.reference_type == 'Sellable' && !line_item.sellable.unlimited_inventory }
    
    attr_accessible :sellable_id, :price, :total, :description, :quantity
    
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
