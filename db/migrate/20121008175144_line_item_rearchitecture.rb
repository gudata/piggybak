class LineItemRearchitecture < ActiveRecord::Migration
  def up
    add_column :line_items, :reference_type, :string, :null => false, :default => "sellable"
    rename_column :line_items, :price, :unit_price
    rename_column :line_items, :total, :price
    rename_column :line_items, :sellable_id, :reference_id
    add_column :line_items, :sort, :integer, :null => false, :default => 0
    change_table(:line_items) do |t|
      t.timestamps
    end

    #[Piggybak::Shipment, Piggybak::Payment, Piggybak::Adjustment].each do |klass|
    #  klass.all.each do |item|
        # create line item here with total and sort
    #  end
    #end

    #Piggybak::Order.all.each do |order|
      # create line item here with total and sort
    #end

    add_column :shipments, :line_item_id, :integer
    add_column :payments, :line_item_id, :integer
    add_column :adjustments, :line_item_id, :integer

    remove_column :shipments, :total
    remove_column :payments, :total
    remove_column :adjustments, :total
    remove_column :shipments, :order_id
    remove_column :payments, :order_id
    remove_column :adjustments, :order_id
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
  end
end
