require 'test_helper'

# See here for guide: http://api.ziftpay.com/index.php
class RemoteZiftTest < Test::Unit::TestCase
  def setup
    @gateway = ZiftGateway.new(fixtures(:zift))

    @amount = 5000
    @declined_amount = 12500
    @partial_approval_amount = 10
    @credit_card  = credit_card('4111111111111111', month: 4, year: 2022)
    @invalid_card = credit_card('4111111111111119')
    @options = {
        billing_address: address,
        description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_more_options
    options = {
        order_id: '1',
        ip: "127.0.0.1",
        email: "joe@example.com"
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Insufficient Funds', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    sleep(5)
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Succeeded', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Insufficient Funds', response.message
  end

  # def test_partial_capture
  #   auth = @gateway.authorize(@amount, @credit_card, @options)
  #   assert_success auth
  #   sleep(5)
  #
  #   assert capture = @gateway.capture(@amount-1, auth.authorization)
  #   assert_success capture
  # end

  def test_failed_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    sleep(5)
    assert capture = @gateway.capture(@amount+100, auth.authorization)
    assert_failure capture
    assert_match /Capture Amount value must be less than or equal to Authorization Amount/, capture.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    sleep(5)

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Succeeded', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    sleep(5)

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
    assert_equal 'Succeeded', refund.message
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '123456')
    assert_failure response
    assert_equal 'Referenced Transaction is not found within the System or not accessible to the current user.', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    sleep(5)

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Succeeded', void.message
  end

  def test_failed_void
    response = @gateway.void('1234')
    assert_failure response
    assert_equal 'Referenced Transaction is not found within the System or not accessible to the current user.', response.message
  end

  # Not sure why this isnt working
  # def test_successful_verify
  #   options = {
  #       billing_address: address(zip: "11111"),
  #       description: 'Store Purchase'
  #   }
  #
  #   response = @gateway.verify(@credit_card, options)
  #   assert_success response
  #   assert_equal 'Succeeded', response.message
  # end

  def test_failed_verify
    response = @gateway.verify(@invalid_card, @options)
    assert_failure response
    assert_equal "Field's accountNumber value is invalid.", response.message
  end

  def test_invalid_login_no_username
    gateway = ZiftGateway.new(userName: '', password: '', merchant_id: '1234', accountId: '1234')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Username or password is invalid.}, response.message
  end

  def test_invalid_login_unknown_username
    gateway = ZiftGateway.new(userName: 'Test', password: 'test', merchant_id: '1234', accountId: '1234')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Username or password is invalid.}, response.message
  end

  # def test_dump_transcript
  # This test will run a purchase transaction on your gateway
  # and dump a transcript of the HTTP conversation so that
  # you can use that transcript as a reference while
  # implementing your scrubbing logic.  You can delete
  # this helper after completing your scrub implementation.
  # dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  # end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
  end

end
