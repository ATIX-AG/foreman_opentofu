module ForemanOpentofu
  class HclFormatTest < ActiveSupport::TestCase
    let(:subject) { Class.new { extend HclFormat } }

    test 'block_to_hcl' do
      assert_equal "\nhello ", subject.block_to_hcl(['hello'])
      assert_equal "\nthis \"is\" \"a\" \"test\" ", subject.block_to_hcl(%w[this is a test])
      assert_equal "\nthis \"is\" \"a\" \"test\" 123", subject.block_to_hcl(%w[this is a test], 123)
      assert_equal "\n  this \"is\" \"a\" \"test\" ", subject.block_to_hcl(%w[this is a test], nil, depth: 1)
      assert_equal "\n  this \"is\" \"a\" \"test\" {}", subject.block_to_hcl(%w[this is a test], {}, depth: 1)
    end

    test 'hash_to_hcl' do
      assert_equal '{}', subject.hash_to_hcl({}, {})
      assert_equal '{}', subject.hash_to_hcl({}, depth: 1)
      assert_equal '{
    foo = "bar"
  }', subject.hash_to_hcl({ foo: 'bar' }, depth: 1)
      assert_equal '{
  foo = "bar"
  Hello = "World"
}', subject.hash_to_hcl({ :foo => 'bar', 'Hello' => 'World' }, {})
      assert_equal '{
  foo = {
    Hello = "World"
  }
}', subject.hash_to_hcl({ foo: { 'Hello' => 'World' } }, {})
    end

    test 'array_to_hcl' do
      assert_equal '[]', subject.array_to_hcl([], {})
      assert_equal '[]', subject.array_to_hcl([], depth: 1)
      assert_equal '[
  "abc",
  "xyz"
]', subject.array_to_hcl(%w[abc xyz], {})
      assert_equal '[
    123,
    456
  ]', subject.array_to_hcl([123, 456], depth: 1)
      assert_equal '[
  [
    "abc",
    "xyz"
  ],
  [
    123
  ],
  []
]', subject.array_to_hcl([%w[abc xyz], [123], []], {})
    end

    test 'to_hcl' do
      assert_equal '', subject.to_hcl(nil)
      assert_equal '"help"', subject.to_hcl('help')
      assert_equal '42', subject.to_hcl(42)
      assert_equal '', subject.to_hcl(nil)
      assert_snapshot self, 'to_hcl', subject.to_hcl({
        :hash => {
          bool: true,
          string: 'Hello "World"!',
          number: 123_456,
          list: [1, 2, 3, 4, 5],
        },
        :list => %w[abc xyz],
        'String' => 'works',
      })
    end
  end
end
