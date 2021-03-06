require 'test_helper'

# Test Models:
#
#   Answer       - :scope => :question_id
#   Comment      - :scope => :question_id (with an AR default scope)
#   Invoice      - :scope => :account_id, :start_at => 1000
#   Product      - :scope => :account_id, :start_at => lambda { |r| r.computed_start_value }
#   Order        - :scope => :non_existent_column
#   User         - :scope => :account_id, :column => :custom_sequential_id
#   Address      - :scope => :account_id ('sequential_id' does not exist)
#   Email        - :scope => [:emailable_id, :emailable_type]
#   Subscription - no options
#   Rating       - :scope => :comment_id, skip: { |r| r.score == 0 }

class SequencedTest < ActiveSupport::TestCase
  test "default start_at" do
    question = Question.create
    answer = question.answers.create
    assert_equal 1, answer.sequential_id
  end

  test "custom start_at" do
    account = Account.create
    invoice = account.invoices.create
    assert_equal 1000, invoice.sequential_id

    another_invoice = account.invoices.create
    assert_equal 1001, another_invoice.sequential_id
  end

  test "lambda start_at" do
    account = Account.create
    product = Product.create(:account_id => account.id)
    assert_equal 3, product.sequential_id

    another_product = Product.create(:account_id => account.id)
    assert_equal 4, another_product.sequential_id
  end

  test "custom start_at with populated table" do
    account = Account.create
    account.invoices.create(:sequential_id => 1)
    invoice = account.invoices.create
    assert_equal 1000, invoice.sequential_id
  end

  test "sequential id increment" do
    question = Question.create
    question.answers.create(:sequential_id => 10)
    another_answer = question.answers.create
    assert_equal 11, another_answer.sequential_id
  end

  test "default scope" do
    Subscription.create(:sequential_id => 1)
    subscription = Subscription.create
    assert_equal 2, subscription.sequential_id
  end

  test "undefined scope method" do
    account = Account.create
    order = account.orders.build
    assert_raises(ArgumentError) { order.save }
  end

  test "scope method returns nil" do
    answer = Answer.new
    assert_raises(ArgumentError) { answer.save }
  end

  test "custom sequential id column" do
    account = Account.create
    user = account.users.create
    assert_equal 1, user.custom_sequential_id
  end

  test "sequential id remains on save" do
    question = Question.create
    answer = question.answers.create
    assert_equal 1, answer.sequential_id

    answer.reload
    answer.body = "Updated body"
    answer.save
    assert_equal 1, answer.sequential_id
  end

  test "undefined sequential id column" do
    account = Account.create
    address = account.addresses.build
    assert_raises(ArgumentError) { address.save }
  end

  test "manually setting sequential id" do
    question = Question.create
    answer = question.answers.build(:sequential_id => 10)
    another_answer = question.answers.build(:sequential_id => 10)
    answer.save
    another_answer.save

    assert_equal 10, answer.sequential_id
    assert_equal 10, another_answer.sequential_id
  end

  test "model with a default scope for sorting" do
    question = Question.create
    (1..3).each { |id| question.comments.create(:sequential_id => id) }
    comment = question.comments.create
    assert_equal 4, comment.sequential_id
  end

  test "multi-column scopes" do
    Email.create(:emailable_id => 1, :emailable_type => "User", :sequential_id => 2)
    Email.create(:emailable_id => 1, :emailable_type => "Question", :sequential_id => 3)
    email = Email.create(:emailable_id => 1, :emailable_type => "User")
    assert_equal 3, email.sequential_id
  end

  test "skip option" do
    rating = Rating.create(:comment_id => 1, :score => 1)
    assert_equal 1, rating.sequential_id

    rating = Rating.create(:comment_id => 1, :score => 0)
    assert_equal nil, rating.sequential_id
  end

  test 'promote up' do
    boss=Boss.create({:name=>'boss1'})
		puts 'promote up'
    Promotable.create({:name=>'Promotable1',:boss_id=>boss.id})
    previous=Promotable.create({:name=>'Promotable2',:boss_id=>boss.id})
    promotable=Promotable.create({:name=>'Promotable3',:boss_id=>boss.id})
    Promotable.create({:name=>'Promotable4',:boss_id=>boss.id})
    Promotable.create({:name=>'Promotable5',:boss_id=>boss.id})

    assert_equal promotable.promote(:up),true
    newprev=Promotable.find(previous.id)
    newpromoted=Promotable.find(promotable.id)

    assert_equal previous.sequential_id, newpromoted.sequential_id
    assert_equal promotable.id,newprev.sequential_id
  end

  test 'promote down' do
    boss=Boss.create({:name=>'boss1'})
    Promotable.create({:name=>'Promotable1',:boss_id=>boss.id})
    Promotable.create({:name=>'Promotable2',:boss_id=>boss.id})
    promotable=Promotable.create({:name=>'Promotable3',:boss_id=>boss.id})
    nextinline=Promotable.create({:name=>'Promotable4',:boss_id=>boss.id})
    Promotable.create({:name=>'Promotable5',:boss_id=>boss.id})

    assert_equal promotable.promote(:down),true
    newnextinline=Promotable.find(nextinline.id)
    newpromoted=Promotable.find(promotable.id)

    assert_equal nextinline.sequential_id, newpromoted.sequential_id
    assert_equal promotable.id,newnextinline.sequential_id
  end

  test 'promote up edgecase-overflow' do
    Promotable.destroy_all
    boss=Boss.create({:name=>'boss1'})

    promotable=Promotable.create({:name=>'Promotable1',:boss_id=>boss.id})

    assert_equal promotable.promote(:up),false
	end

	test 'promote! up edgecase-overflow raises exception' do
		Promotable.destroy_all
		boss=Boss.create({:name=>'boss1'})

		promotable=Promotable.create({:name=>'Promotable1',:boss_id=>boss.id})

		assert_raises(Exception){promotable.promote!(:up)}

		begin
			promotable.promote!(:up)
		rescue Exception=>e
			assert_equal e.message,'Promotion beyond bounding is not allowed. It is suggested to use sanitize_sequence if really needed.'
		end

	end

  test 'promote down edgecase-overflow' do
    Promotable.destroy_all
    boss=Boss.create({:name=>'boss1'})

    promotable=Promotable.create({:name=>'Promotable1',:boss_id=>boss.id})

		assert_equal promotable.promote(:down),false
  end

	test 'promote! down edgecase-overflow raises exception' do
		Promotable.destroy_all
		boss=Boss.create({:name=>'boss1'})

		promotable=Promotable.create({:name=>'Promotable1',:boss_id=>boss.id})

		assert_raises(Exception){promotable.promote!(:down)}

		begin
			promotable.promote!(:down)
		rescue Exception=>e
			assert_equal e.message,'Promotion beyond bounding is not allowed. It is suggested to use sanitize_sequence if really needed.'
		end

	end

  test 'sanitization test' do
    Promotable.destroy_all
		boss=Boss.create({:name=>'boss1'})
    p1=Promotable.create({:name=>'Promotable1',:boss_id=>boss.id,:sequential_id=>1})
    p2=Promotable.create({:name=>'Promotable2',:boss_id=>boss.id,:sequential_id=>3})
    p3=Promotable.create({:name=>'Promotable3',:boss_id=>boss.id,:sequential_id=>4})
    p4=Promotable.create({:name=>'Promotable4',:boss_id=>boss.id,:sequential_id=>7})
    p5=Promotable.create({:name=>'Promotable5',:boss_id=>boss.id,:sequential_id=>12})
    p1.sanitize_sequence()

    np1=Promotable.find(p1.id)
    np2=Promotable.find(p2.id)
    np3=Promotable.find(p3.id)
    np4=Promotable.find(p4.id)
    np5=Promotable.find(p5.id)

    assert_equal 1,np1.sequential_id
    assert_equal 2,np2.sequential_id
    assert_equal 3,np3.sequential_id
    assert_equal 4,np4.sequential_id
    assert_equal 5,np5.sequential_id
	end

	test 'get_sequence_top' do
		Promotable.destroy_all
		boss=Boss.create({:name=>'boss1'})
		p1=Promotable.create({:name=>'Promotable1',:boss_id=>boss.id,:sequential_id=>1})
		p2=Promotable.create({:name=>'Promotable2',:boss_id=>boss.id,:sequential_id=>3})
		p3=Promotable.create({:name=>'Promotable3',:boss_id=>boss.id,:sequential_id=>4})
		p4=Promotable.create({:name=>'Promotable4',:boss_id=>boss.id,:sequential_id=>7})
		p5=Promotable.create({:name=>'Promotable5',:boss_id=>boss.id,:sequential_id=>12})

		assert p3.get_sequence_top.id==p1.id
	end

	test 'get_sequence_bottom' do
		Promotable.destroy_all
		boss=Boss.create({:name=>'boss1'})
		p1=Promotable.create({:name=>'Promotable1',:boss_id=>boss.id,:sequential_id=>1})
		p2=Promotable.create({:name=>'Promotable2',:boss_id=>boss.id,:sequential_id=>3})
		p3=Promotable.create({:name=>'Promotable3',:boss_id=>boss.id,:sequential_id=>4})
		p4=Promotable.create({:name=>'Promotable4',:boss_id=>boss.id,:sequential_id=>7})
		p5=Promotable.create({:name=>'Promotable5',:boss_id=>boss.id,:sequential_id=>12})

		assert p3.get_sequence_bottom.id==p5.id
	end

	test 'promote_to' do
		Promotable.destroy_all
		boss=Boss.create({:name=>'boss1'})
		p1=Promotable.create({:name=>'Promotable1',:boss_id=>boss.id,:sequential_id=>1})
		p2=Promotable.create({:name=>'Promotable2',:boss_id=>boss.id,:sequential_id=>3})
		p3=Promotable.create({:name=>'Promotable3',:boss_id=>boss.id,:sequential_id=>4})
		p4=Promotable.create({:name=>'Promotable4',:boss_id=>boss.id,:sequential_id=>7})
		p5=Promotable.create({:name=>'Promotable5',:boss_id=>boss.id,:sequential_id=>12})

		oldp3seq=p3.sequential_id
		p3.promote_to(1)

		assert Promotable.find(p3.id).sequential_id==1
		assert Promotable.find(p1.id).sequential_id==oldp3seq
	end

	test 'promote_to!' do
		Promotable.destroy_all
		boss=Boss.create({:name=>'boss1'})
		p1=Promotable.create({:name=>'Promotable1',:boss_id=>boss.id,:sequential_id=>1})
		p2=Promotable.create({:name=>'Promotable2',:boss_id=>boss.id,:sequential_id=>3})
		p3=Promotable.create({:name=>'Promotable3',:boss_id=>boss.id,:sequential_id=>4})

		assert Promotable.find(p3.id).sequential_id==4
		assert_raise(Exception){p3.promote_to!(12)}
	end

  test 'promote_to custom id' do
    account = Account.create
    user1 = account.users.create
    assert_equal 1, user1.custom_sequential_id
    user2 = account.users.create
    assert_equal 2, user2.custom_sequential_id
    user3 = account.users.create
    assert_equal 3, user3.custom_sequential_id

    user1.promote_to(3)
    assert_equal 3, user1.custom_sequential_id
    assert_equal 2, user2.custom_sequential_id
  end

	test 'get_scoped_records' do
		boss1=Boss.create({:name=>'boss1'})
		boss2=Boss.create({:name=>'boss2'})
		p1=Promotable.create({:name=>'Promotable1',:boss_id=>boss1.id,:sequential_id=>1})
		p2=Promotable.create({:name=>'Promotable2',:boss_id=>boss2.id,:sequential_id=>3})
		p3=Promotable.create({:name=>'Promotable3',:boss_id=>boss1.id,:sequential_id=>4})
		p4=Promotable.create({:name=>'Promotable4',:boss_id=>boss2.id,:sequential_id=>7})
		p5=Promotable.create({:name=>'Promotable5',:boss_id=>boss1.id,:sequential_id=>12})

		scoped_rec1=p1.get_scoped_records

		assert scoped_rec1.include? p1
		assert !(scoped_rec1.include? p2)
		assert scoped_rec1.include? p3
		assert !(scoped_rec1.include? p4)
		assert scoped_rec1.include? p5
	end

end
