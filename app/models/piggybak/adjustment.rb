module Piggybak
  class Adjustment < ActiveRecord::Base
    belongs_to :order
    belongs_to :source, :polymorphic => true
    attr_accessor :user_id
    belongs_to :line_item

    validates_presence_of :source

    before_validation :set_source
    
    def set_source
      if self.source.nil? && self.user_id.present?
        self.source = User.find(self.user_id)
      end
    end

    def admin_label
      if !self.new_record? 
        return "Adjustment ##{self.id} (#{self.created_at.strftime("%m-%d-%Y")}): " #+ 
          #"$#{"%.2f" % self.total}"
      else
        return ""
      end
    end
  end
end
