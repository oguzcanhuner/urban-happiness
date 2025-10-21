# frozen_string_literal: true

# Processes bulk orders and applies various business rules
class OrderProcessor
  def initialize(orders, inventory)
    @orders = orders
    @inventory = inventory
  end

  def process
    results = []

    @orders.each do |order|
      available = true
      order[:items].each do |item|
        inventory_item = nil
        @inventory.each do |inv|
          if inv[:sku] == item[:sku]
            inventory_item = inv
            break
          end
        end

        if !inventory_item || inventory_item[:quantity] < item[:quantity]
          available = false
          break
        end
      end

      next unless available

      subtotal = 0
      order[:items].each do |item|
        product = nil
        @inventory.each do |inv|
          if inv[:sku] == item[:sku]
            product = inv
            break
          end
        end
        subtotal += product[:price] * item[:quantity]
      end

      discount = 0
      if order[:customer_type] == 'vip'
        discount = subtotal * 0.15
      elsif order[:customer_type] == 'regular' && subtotal > 100
        discount = subtotal * 0.10
      end

      total_items = 0
      order[:items].each do |item|
        total_items += item[:quantity]
      end

      if total_items >= 10
        bulk_discount = subtotal * 0.05
        discount = bulk_discount if bulk_discount > discount
      end

      total_before_tax = subtotal - discount
      tax = subtotal * 0.08

      total = total_before_tax + tax

      results << {
        order_id: order[:id],
        subtotal: subtotal.round(2),
        discount: discount.round(2),
        tax: tax.round(2),
        total: total.round(2),
        status: 'processed'
      }
    end

    results
  end

  def low_stock_alerts(threshold = 10)
    alerts = []

    @inventory.each do |item|
      next unless item[:quantity] < threshold

      # Find all orders that contain this item
      order_count = 0
      @orders.each do |order|
        order[:items].each do |order_item|
          order_count += 1 if order_item[:sku] == item[:sku]
        end
      end

      alerts << {
        sku: item[:sku],
        current_quantity: item[:quantity],
        pending_orders: order_count
      }
    end

    alerts
  end
end
