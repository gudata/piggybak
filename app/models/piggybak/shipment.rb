module Piggybak
  class Shipment < ActiveRecord::Base
    belongs_to :order
    acts_as_changer
    belongs_to :shipping_method
    has_one :line_item, :as => "reference", :class_name => "::Piggybak::LineItem"

    validates_presence_of :status
    validates_presence_of :shipping_method_id
    
    attr_accessible :shipping_method_id
    
    def status_enum
      ["new", "processing", "shipped"]
    end

    def admin_label
      "Shipment ##{self.id}<br />" +
      "#{self.shipping_method.description}<br />" +
      "Status: #{self.status}<br />" #+
      #"$#{"%.2f" % self.total}" reference line item total here instead
    end
  end
end
