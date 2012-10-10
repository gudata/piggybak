module Piggybak
  class Order < ActiveRecord::Base
    has_many :line_items, :inverse_of => :order
    has_many :order_notes, :inverse_of => :order

    belongs_to :billing_address, :class_name => "Piggybak::Address"
    belongs_to :shipping_address, :class_name => "Piggybak::Address"
    belongs_to :user
  
    accepts_nested_attributes_for :billing_address, :allow_destroy => true
    accepts_nested_attributes_for :shipping_address, :allow_destroy => true
    accepts_nested_attributes_for :line_items, :allow_destroy => true
    accepts_nested_attributes_for :order_notes

    attr_accessor :recorded_changes
    attr_accessor :recorded_changer
    attr_accessor :was_new_record
    attr_accessor :disable_order_notes

    validates_presence_of :status, :email, :phone, :total, :total_due, :created_at, :ip_address, :user_agent

    after_initialize :initialize_defaults
    before_validation :prepare_for_destruction
    after_validation :update_totals
    before_save :process_payments, :update_status, :set_new_record
    after_save :record_order_note

    default_scope :order => 'created_at DESC'

    attr_accessible :email, :phone, :billing_address_attributes, 
                    :shipping_address_attributes, :payments_attributes,
                    :shipments_attributes
                    
    def initialize_defaults
      self.recorded_changes ||= []

      self.billing_address ||= Piggybak::Address.new
      self.shipping_address ||= Piggybak::Address.new

      self.ip_address ||= 'admin'
      self.user_agent ||= 'admin'

      self.created_at ||= Time.now
      self.status ||= "new"
      self.total ||= 0
      self.total_due ||= 0
      self.disable_order_notes = false
    end

    def initialize_user(user, on_post)
      if user
        self.user = user
        self.email = user.email 
      end
    end

    def process_payments
      has_errors = false

      self.line_items.select { |li| li.line_item_type == "payment" }.each do |line_item|
        if line_item.payment.process(self)
          line_item.price = self.total_due
          self.total_due = 0
        else
          return false
        end
      end 

      true
    end

    def record_order_note
      if self.changed? && !self.was_new_record
        self.recorded_changes << self.formatted_changes
      end

      if self.recorded_changes.any? && !self.disable_order_notes
        OrderNote.create(:order_id => self.id, :note => self.recorded_changes.join("<br />"), :user_id => self.recorded_changer.to_i)
      end
    end

    def add_line_items(cart)
      cart.update_quantities
      cart.items.each do |item|
        line_item = Piggybak::LineItem.new({ :reference_id => item[:sellable].id,
          :reference_type => "Sellable",
          :unit_price => item[:sellable].price,
          :price => item[:sellable].price*item[:quantity],
          :description => item[:sellable].description,
          :quantity => item[:quantity] })
        self.line_items << line_item
      end
    end

    def set_defaults
      #return if self.to_be_cancelled

=begin
      self.line_items.each do |line_item|
        if self.status != "shipped"
          line_item.description = line_item.sellable.description
          line_item.price = line_item.sellable.price
        end
        if line_item.sellable
          line_item.total = line_item.price * line_item.quantity.to_i
        else
          line_item.total = 0
        end
      end
=end
    end

    def prepare_for_destruction
      self.line_items.each do |line_item|
        if line_item.quantity == 0
          line_item.mark_for_destruction
        end
      end
    end

    def update_totals
      self.total = 0
      self.total_due = 0
Rails.logger.warn "stephie: #{self.errors.inspect}"

      if self.line_items.taxes.any?
        self.line_items.taxes.each do |line_item|
          line_item.destroy
        end
      end

      tax = TaxMethod.calculate_tax(self)
      if tax > 0
        LineItem.create({ :order_id => self.id, :quantity => 1, :description => "Tax Charge", :price => tax })
      end

      self.line_items.each do |line_item|
        if !line_item._destroy
          self.total += line_item.price if line_item.price.to_f > 0
          self.total_due += line_item.price.to_f
        end
      end
    end

    def update_status
      return if self.status == "cancelled"  # do nothing

      if self.total_due != 0.00
        self.status = "unbalanced" 
      else
        if self.to_be_cancelled
          self.status = "cancelled"
        elsif line_items.select { |li| li.line_item_type == "shipment" }.any? && line_items.select { |li| li.line_item_type == "shipment" }.all? { |s| s.shipment.status == "shipped" }
          self.status = "shipped"
        elsif line_items.select { |li| li.line_item_type == "shipment" }.any? && line_items.select { |li| li.line_item_type == "shipment" }.all? { |s| s.shipment.status == "processing" }
          self.status = "processing"
        else
          self.status = "new"
        end
      end
    end
    def set_new_record
      self.was_new_record = self.new_record?

      true
    end

    def status_enum
      ["new", "processing", "shipped"]
    end
      
    def avs_address
      {
      :address1 => self.billing_address.address1,
      :city     => self.billing_address.city,
      :state    => self.billing_address.state_display,
      :zip      => self.billing_address.zip,
      :country  => "US" 
      }
    end

    def admin_label
      "Order ##{self.id}"    
    end

    def subtotal
      v = 0

      # change to view line_items.sellables
      self.line_items.each do |line_item|
        if !line_item._destroy
          v += line_item.total 
        end
      end

      v
    end
  end
end
