class LineItemRearchitecture < ActiveRecord::Migration
  def up
    add_column :line_items, :line_item_type, :string, :null => false, :default => "sellable"
    add_column :line_items, :reference_type, :string, :default => "Piggybak::Sellable"
    rename_column :line_items, :price, :unit_price
    rename_column :line_items, :total, :price
    rename_column :line_items, :sellable_id, :reference_id
    change_column :line_items, :reference_id, :integer, :null => true
    add_column :line_items, :sort, :integer, :null => false, :default => 0
    change_table(:line_items) do |t|
      t.timestamps
    end

    add_column :shipments, :line_item_id, :integer
    add_column :payments, :line_item_id, :integer

    [Piggybak::Shipment, Piggybak::Payment, Piggybak::Adjustment].each do |klass|
      klass.all.each do |item|
        description = ''
        reference_id = reference_type = nil
        if klass == Piggybak::Shipment
          reference_id = item.id
          reference_type = klass.to_s
          description = item.shipping_method.description
        elsif klass == Piggybak::Payment
          reference_id = item.id
          reference_type = klass.to_s
          description = "Payment"
        elsif klass == Piggybak::Adjustment
          description = item.note || "Adjustment"
        end
        li = Piggybak::LineItem.new({ :line_item_type => klass.to_s.demodulize.downcase,
          :reference_id => reference_id,
          :reference_type => reference_type,
          :price => 0.00,
          :description => description,
          :quantity => 1, 
          :order_id => item.order_id })
        li.save

        if [Piggybak::Shipment, Piggybak::Payment].include?(klass)
          item.update_attribute(:line_item_id, li.id)
        end

        li.update_attribute(:price, item.total)
      end
    end

    remove_column :shipments, :total
    remove_column :payments, :total
    remove_column :adjustments, :total
    remove_column :shipments, :order_id
    remove_column :payments, :order_id
    remove_column :adjustments, :order_id

    Piggybak::Order.all.each do |o|
      next if o.attributes["tax_charge"] == 0.00
      o.line_items << Piggybak::LineItem.new({ :line_item_type => "tax",
        :price => o.attributes["tax_charge"],
        :description => "Tax Charge",
        :quantity => 1 })
    end

    remove_column :orders, :tax_charge
  end

  def down
    remove_column :line_items, :updated_at
    remove_column :line_items, :created_at
    remove_column :line_items, :sort
    remove_column :line_items, :reference_type
    rename_column :line_items, :price, :total
    rename_column :line_items, :unit_price, :price
    rename_column :line_items, :reference_id, :sellable_id

    # Populate shipping, payments, adjusments, tax charge with values
    # Delete line items for shipment, payment, adjustment, tax

    add_column :shipments, :total, :decimal, :null => false, :default => 0.0
    add_column :payments, :total, :decimal, :null => false, :default => 0.0
    add_column :adjustments, :total, :decimal
    add_column :shipments, :order_id, :integer, :null => false
    add_column :payments, :order_id, :integer, :null => false
    add_column :adjustments, :order_id, :integer, :null => false

    add_column :orders, :tax_charge, :decimal, :null => false, :default => 0.0
  end
end
