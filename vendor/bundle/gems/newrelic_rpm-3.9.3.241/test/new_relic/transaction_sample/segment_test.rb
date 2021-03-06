# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test_helper'))
require 'new_relic/transaction_sample/segment'
class NewRelic::TransactionSample::SegmentTest < Minitest::Test
  def test_segment_creation
    # basic smoke test
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')
    assert_equal NewRelic::TransactionSample::Segment, s.class
  end

  def test_readers
    t = Time.now
    s = NewRelic::TransactionSample::Segment.new(t, 'Custom/test/metric')
    assert_equal(t, s.entry_timestamp)
    assert_equal(nil, s.exit_timestamp)
    assert_equal(nil, s.parent_segment)
    assert_equal('Custom/test/metric', s.metric_name)
    assert_equal(s.object_id, s.segment_id)
  end

  def test_end_trace
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')
    t = Time.now
    s.end_trace(t)
    assert_equal(t, s.exit_timestamp)
  end

  def test_add_called_segment
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')
    assert_equal [], s.called_segments
    fake_segment = mock('segment')
    fake_segment.expects(:parent_segment=).with(s)
    s.add_called_segment(fake_segment)
    assert_equal([fake_segment], s.called_segments)
  end

  def test_to_s
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')
    s.expects(:to_debug_str).with(0)
    s.to_s
  end

  def test_to_array
    parent = NewRelic::TransactionSample::Segment.new(1, 'Custom/test/parent')
    parent.params[:test] = 'value'
    child = NewRelic::TransactionSample::Segment.new(2, 'Custom/test/child')
    child.end_trace(3)
    parent.add_called_segment(child)
    parent.end_trace(4)
    expected_array = [1000, 4000, 'Custom/test/parent', {:test => 'value'},
                      [[2000, 3000, 'Custom/test/child', {}, []]]]
    assert_equal(expected_array, parent.to_array)
  end

  def test_to_array_with_bad_values
    segment = NewRelic::TransactionSample::Segment.new(nil, nil)
    segment.end_trace(Rational(10, 1))
    expected = [0, 10_000.0, "<unknown>", {}, []]
    assert_equal(expected, segment.to_array)
  end

  if RUBY_VERSION >= '1.9.2'
    def test_to_json
      parent = NewRelic::TransactionSample::Segment.new(1, 'Custom/test/parent')
      parent.params[:test] = 'value'
      child = NewRelic::TransactionSample::Segment.new(2, 'Custom/test/child')
      child.end_trace(3)
      parent.add_called_segment(child)
      parent.end_trace(4)
      expected_string = "[1000,4000,\"Custom/test/parent\",{\"test\":\"value\"},[[2000,3000,\"Custom/test/child\",{},[]]]]"
      assert_equal(expected_string, parent.to_json)
    end
  end

  def test_path_string
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')
    assert_equal("Custom/test/metric[]", s.path_string)

    fake_segment = mock('segment')
    fake_segment.expects(:parent_segment=).with(s)
    fake_segment.expects(:path_string).returns('Custom/other/metric[]')


    s.add_called_segment(fake_segment)
    assert_equal("Custom/test/metric[Custom/other/metric[]]", s.path_string)
  end

  def test_to_s_compact
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')
    assert_equal("Custom/test/metric", s.to_s_compact)

    fake_segment = mock('segment')
    fake_segment.expects(:parent_segment=).with(s)
    fake_segment.expects(:to_s_compact).returns('Custom/other/metric')
    s.add_called_segment(fake_segment)

    assert_equal("Custom/test/metric{Custom/other/metric}", s.to_s_compact)
  end

  def test_to_debug_str_basic
    s = NewRelic::TransactionSample::Segment.new(0.0, 'Custom/test/metric')
    assert_equal(">>   0 ms [Segment] Custom/test/metric \n<<  n/a Custom/test/metric\n", s.to_debug_str(0))
  end

  def test_to_debug_str_with_params
    s = NewRelic::TransactionSample::Segment.new(0.0, 'Custom/test/metric')
    s.params = {:whee => 'a param'}
    assert_equal(">>   0 ms [Segment] Custom/test/metric \n    -whee            : a param\n<<  n/a Custom/test/metric\n", s.to_debug_str(0))
  end

  def test_to_debug_str_closed
    s = NewRelic::TransactionSample::Segment.new(0.0, 'Custom/test/metric')
    s.end_trace(0.1)
    assert_equal(">>   0 ms [Segment] Custom/test/metric \n<< 100 ms Custom/test/metric\n", s.to_debug_str(0))
  end

  def test_to_debug_str_closed_with_nonnumeric
    s = NewRelic::TransactionSample::Segment.new(0.0, 'Custom/test/metric')
    s.end_trace("0.1")
    assert_equal(">>   0 ms [Segment] Custom/test/metric \n<< 0.1 Custom/test/metric\n", s.to_debug_str(0))
  end

  def test_to_debug_str_one_child
    s = NewRelic::TransactionSample::Segment.new(0.0, 'Custom/test/metric')
    s.add_called_segment(NewRelic::TransactionSample::Segment.new(0.1, 'Custom/test/other'))
    assert_equal(">>   0 ms [Segment] Custom/test/metric \n  >> 100 ms [Segment] Custom/test/other \n  <<  n/a Custom/test/other\n<<  n/a Custom/test/metric\n", s.to_debug_str(0))
    # try closing it
    s.called_segments.first.end_trace(0.15)
    s.end_trace(0.2)
    assert_equal(">>   0 ms [Segment] Custom/test/metric \n  >> 100 ms [Segment] Custom/test/other \n  << 150 ms Custom/test/other\n<< 200 ms Custom/test/metric\n", s.to_debug_str(0))
  end

  def test_to_debug_str_multichild
    s = NewRelic::TransactionSample::Segment.new(0.0, 'Custom/test/metric')
    s.add_called_segment(NewRelic::TransactionSample::Segment.new(0.1, 'Custom/test/other'))
    s.add_called_segment(NewRelic::TransactionSample::Segment.new(0.11, 'Custom/test/extra'))
    assert_equal(">>   0 ms [Segment] Custom/test/metric \n  >> 100 ms [Segment] Custom/test/other \n  <<  n/a Custom/test/other\n  >> 110 ms [Segment] Custom/test/extra \n  <<  n/a Custom/test/extra\n<<  n/a Custom/test/metric\n", s.to_debug_str(0))
    ending = 0.12
    s.called_segments.each { |x| x.end_trace(ending += 0.01) }
    s.end_trace(0.2)
    assert_equal(">>   0 ms [Segment] Custom/test/metric \n  >> 100 ms [Segment] Custom/test/other \n  << 130 ms Custom/test/other\n  >> 110 ms [Segment] Custom/test/extra \n  << 140 ms Custom/test/extra\n<< 200 ms Custom/test/metric\n", s.to_debug_str(0))
  end

  def test_to_debug_str_nested
    inner = NewRelic::TransactionSample::Segment.new(0.2, 'Custom/test/inner')
    middle = NewRelic::TransactionSample::Segment.new(0.1, 'Custom/test/middle')
    s = NewRelic::TransactionSample::Segment.new(0.0, 'Custom/test/metric')
    middle.add_called_segment(inner)
    s.add_called_segment(middle)
    assert_equal(">>   0 ms [Segment] Custom/test/metric \n  >> 100 ms [Segment] Custom/test/middle \n    >> 200 ms [Segment] Custom/test/inner \n    <<  n/a Custom/test/inner\n  <<  n/a Custom/test/middle\n<<  n/a Custom/test/metric\n", s.to_debug_str(0))

    # close them
    inner.end_trace(0.21)
    middle.end_trace(0.22)
    s.end_trace(0.23)
    assert_equal(">>   0 ms [Segment] Custom/test/metric \n  >> 100 ms [Segment] Custom/test/middle \n    >> 200 ms [Segment] Custom/test/inner \n    << 210 ms Custom/test/inner\n  << 220 ms Custom/test/middle\n<< 230 ms Custom/test/metric\n", s.to_debug_str(0))
  end

  def test_called_segments_default
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')
    assert_equal([], s.called_segments)
  end

  def test_called_segments_with_segments
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')
    fake_segment = mock('segment')
    fake_segment.expects(:parent_segment=).with(s)
    s.add_called_segment(fake_segment)

    assert_equal([fake_segment], s.called_segments)
  end

  def test_duration
    fake_entry_timestamp = mock('entry timestamp')
    fake_exit_timestamp = mock('exit timestamp')
    fake_result = mock('numeric')
    fake_exit_timestamp.expects(:-).with(fake_entry_timestamp).returns(fake_result)
    fake_result.expects(:to_f).returns(0.5)

    s = NewRelic::TransactionSample::Segment.new(fake_entry_timestamp, 'Custom/test/metric')
    s.end_trace(fake_exit_timestamp)
    assert_equal(0.5, s.duration)
  end

  def test_exclusive_duration_no_children
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')
    s.expects(:duration).returns(0.5)
    assert_equal(0.5, s.exclusive_duration)
  end

  def test_exclusive_duration_with_children
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')

    s.expects(:duration).returns(0.5)

    fake_segment = mock('segment')
    fake_segment.expects(:parent_segment=).with(s)
    fake_segment.expects(:duration).returns(0.1)

    s.add_called_segment(fake_segment)

    assert_equal(0.4, s.exclusive_duration)
  end

  def test_count_segments_default
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')
    assert_equal(1, s.count_segments)
  end

  def test_count_segments_with_children
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')

    fake_segment = mock('segment')
    fake_segment.expects(:parent_segment=).with(s)
    fake_segment.expects(:count_segments).returns(1)

    s.add_called_segment(fake_segment)

    assert_equal(2, s.count_segments)
  end

  def test_key_equals
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')
    # doing this to hold the reference to the hash
    params = {}
    s.params = params
    assert_equal(params, s.params)

    # should delegate to the same hash we have above
    s[:foo] = 'correct'

    assert_equal('correct', params[:foo])
  end

  def test_key
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')
    s.params = {:foo => 'correct'}
    assert_equal('correct', s[:foo])
  end

  def test_params
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')

    # should have a default value
    assert_equal(nil, s.instance_eval { @params })
    assert_equal({}, s.params)

    # should otherwise take the value from the @params var
    s.instance_eval { @params = {:foo => 'correct'} }
    assert_equal({:foo => 'correct'}, s.params)
  end

  def test_each_segment_default
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')
    # in the base case it just yields the block to itself
    count = 0
    s.each_segment do |x|
      count += 1
      assert_equal(s, x)
    end
    # should only run once
    assert_equal(1, count)
  end

  def test_each_segment_with_children
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')

    fake_segment = mock('segment')
    fake_segment.expects(:parent_segment=).with(s)
    fake_segment.expects(:each_segment).yields(fake_segment)

    s.add_called_segment(fake_segment)

    count = 0
    s.each_segment do |x|
      count += 1
    end

    assert_equal(2, count)
  end

  def test_each_segment_with_nest_tracking
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')

    summary = mock('summary')
    summary.expects(:current_nest_count).twice.returns(0).then.returns(1)
    summary.expects(:current_nest_count=).twice
    s.each_segment_with_nest_tracking do |x|
      summary
    end
  end

  def test_find_segment_default
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')
    id_to_find = s.segment_id
    # should return itself in the base case
    assert_equal(s, s.find_segment(id_to_find))
  end

  def test_find_segment_not_found
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')
    assert_equal(nil, s.find_segment(-1))
  end

  def test_find_segment_with_children
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')
    id_to_find = s.segment_id
    # should return itself in the base case
    assert_equal(s, s.find_segment(id_to_find))
  end

  def test_explain_sql_raising_an_error
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')
    config = { :adapter => 'mysql' }
    statement = NewRelic::Agent::Database::Statement.new('SELECT')
    statement.config = config
    statement.explainer = NewRelic::Agent::Instrumentation::ActiveRecord::EXPLAINER
    s.params = {:sql => statement}
    NewRelic::Agent::Database.expects(:get_connection).with(config).raises(RuntimeError.new("whee"))
    s.explain_sql
  end

  def test_explain_sql_can_handle_missing_config
    # If TT segment came over from Resque child, might not be a Statement
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')
    s.params = { :sql => "SELECT * FROM galaxy" }
    s.explain_sql
  end

  def test_explain_sql_can_use_already_existing_plan
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')
    s.params = {
      :sql => "SELECT * FROM galaxy",
      :explain_plan => "EXPLAIN IT!"
    }

    assert_equal("EXPLAIN IT!", s.explain_sql)
  end

  def test_params_equal
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')
    assert_equal(nil, s.instance_eval { @params })

    params = {:foo => 'correct'}

    s.params = params
    assert_equal(params, s.instance_eval { @params })
  end

  def test_obfuscated_sql
    sql = 'select * from table where id = 1'
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')
    s[:sql] = sql
    assert_equal('select * from table where id = ?', s.obfuscated_sql)
  end

  def test_called_segments_equals
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')
    assert_equal(nil, s.instance_eval { @called_segments })
    s.called_segments = [1, 2, 3]
    assert_equal([1, 2, 3], s.instance_eval { @called_segments })
  end

  def test_parent_segment_equals
    s = NewRelic::TransactionSample::Segment.new(Time.now, 'Custom/test/metric')
    assert_equal(nil, s.instance_eval { @parent_segment })
    fake_segment = mock('segment')
    s.send(:parent_segment=, fake_segment)
    assert_equal(fake_segment, s.parent_segment)
  end
end
