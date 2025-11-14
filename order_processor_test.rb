require 'bundler/inline'

gemfile(true, quiet: true) do
  source 'https://rubygems.org'

  gem 'minitest', require: 'minitest/autorun'
  gem 'benchmark'
end

require_relative 'order_processor'

class OrderProcessorTest < Minitest::Test
  def setup
    @inventory = [
      { sku: 'A001', name: 'Widget', price: 10.00, quantity: 100 },
      { sku: 'B002', name: 'Gadget', price: 25.00, quantity: 50 },
      { sku: 'C003', name: 'Doohickey', price: 5.00, quantity: 200 }
    ]
  end

  def test_basic_order_processing
    orders = [
      {
        id: 1,
        customer_type: 'regular',
        items: [{ sku: 'A001', quantity: 2 }]
      }
    ]

    processor = OrderProcessor.new(orders, @inventory)
    results = processor.process

    assert_equal 1, results.length
    assert_equal 20.00, results[0][:subtotal]
    assert_equal 0.00, results[0][:discount]
    assert_equal 1.60, results[0][:tax]
    assert_equal 21.60, results[0][:total]
  end

  def test_vip_discount
    orders = [
      {
        id: 2,
        customer_type: 'vip',
        items: [{ sku: 'B002', quantity: 4 }]
      }
    ]

    processor = OrderProcessor.new(orders, @inventory)
    results = processor.process

    assert_equal 100.00, results[0][:subtotal]
    assert_equal 15.00, results[0][:discount]
    assert_equal 6.80, results[0][:tax]
    assert_equal 91.80, results[0][:total]
  end

  def test_bulk_discount_vs_customer_discount
    orders = [
      {
        id: 3,
        customer_type: 'regular',
        items: [{ sku: 'C003', quantity: 15 }] # 15 items * $5 = $75
      }
    ]

    processor = OrderProcessor.new(orders, @inventory)
    results = processor.process

    # Bulk discount (5%) = $3.75 vs Regular discount (none, < $100) = $0
    # Should apply bulk discount
    assert_equal 75.00, results[0][:subtotal]
    assert_equal 3.75, results[0][:discount]
  end

  def test_insufficient_inventory
    orders = [
      {
        id: 4,
        customer_type: 'regular',
        items: [{ sku: 'A001', quantity: 150 }] # Only 100 available
      }
    ]

    processor = OrderProcessor.new(orders, @inventory)
    results = processor.process

    assert_equal 0, results.length, 'Order should be rejected due to insufficient inventory'
  end

  def test_low_stock_alerts
    orders = [
      { id: 1, items: [{ sku: 'A001', quantity: 1 }] },
      { id: 2, items: [{ sku: 'A001', quantity: 2 }] }
    ]

    inventory_low_stock = [
      { sku: 'A001', price: 10.00, quantity: 5 },  # Below threshold
      { sku: 'B002', price: 25.00, quantity: 50 }  # Above threshold
    ]

    processor = OrderProcessor.new(orders, inventory_low_stock)
    alerts = processor.low_stock_alerts(10)

    assert_equal 1, alerts.length
    assert_equal 'A001', alerts[0][:sku]
    assert_equal 5, alerts[0][:current_quantity]
    assert_equal 2, alerts[0][:pending_orders]
  end

  def test_performance_with_large_dataset
    # Create large dataset: 10_000 orders, 500 inventory items
    large_inventory = 500.times.map do |i|
      { sku: "SKU#{i}", name: "Product #{i}", price: rand(10..100).to_f, quantity: rand(10..100) }
    end

    large_orders = 10_000.times.map do |i|
      {
        id: i,
        customer_type: %w[regular vip].sample,
        items: rand(1..5).times.map { { sku: "SKU#{rand(500)}", quantity: rand(1..3) } }
      }
    end

    processor = OrderProcessor.new(large_orders, large_inventory)

    time = Benchmark.realtime do
      processor.process
    end

    puts "\n⚠️  Performance test took #{time.round(2)}s (With 10_000 orders × 500 inventory items)"
  end
end
