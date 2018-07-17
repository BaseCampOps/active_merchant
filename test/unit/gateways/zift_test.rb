require 'test_helper'

class ZiftTest < Test::Unit::TestCase
  def setup
    @gateway = ZiftGateway.new(userName: 'TestUser', password: '1234', accountId: "1234")
    @credit_card = credit_card
    @amount = 100

    @options = {
        order_id: '1',
        billing_address: address,
        description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '653613', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal nil, response.error_code
    assert_equal "Insufficient Funds", response.message
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '653653', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal nil, response.error_code
    assert_equal "Insufficient Funds", response.message
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, "af267c892f7a11e78c800a12fcf6f1a3", @options)
    assert_success response

    assert_equal '653653', response.authorization
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, "af267c892f7a11e78c800a12fcf6f1a3", @options)
    assert_failure response
    assert_equal nil, response.error_code
    assert_match "Capture Amount value must be less than or equal to Authorization Amount", response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, "653653", @options)
    assert_success response

    assert_equal '653693', response.authorization
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.refund(@amount, "af267c892f7a11e78c800a12fcf6f1a3", @options)
    assert_failure response
    assert_equal nil, response.error_code
    assert_match "Capture Amount value must be less than or equal to Authorization Amount", response.message
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void("653693", @options)
    assert_success response

    assert_equal '653632', response.authorization
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void("653693", @options)
    assert_failure response
    assert_equal nil, response.error_code
    assert_equal "Referenced Transaction is not found within the System or not accessible to the current user.", response.message
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).returns(successful_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal '654283', response.authorization
    assert response.test?
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_equal nil, response.error_code
    assert_equal "Field's accountNumber value is invalid.", response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
opening connection to sandbox-secure.ziftpay.com:443...
opened
starting SSL for sandbox-secure.ziftpay.com:443...
SSL established
<- "POST /gates/xurl? HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: sandbox-secure.ziftpay.com\r\nContent-Length: 363\r\n\r\n"
<- "amount=5000&transactionIndustryType=RE&transactionCategoryType=B&memo=Store+Purchase&accountType=R&accountNumber=4111111111111111&accountAccessory=0422&holderName=Longbob+Longsen&csc=123&street=456+My+Street&city=Ottawa&countryCode=CA&state=ON&zipCode=K1C2N6&userName=api-evtc-ms1804000&password=tUndM195v0fjEJqbN4DydFkV93v4E5L4&accountId=1804001&requestType=sale"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Tue, 17 Jul 2018 16:43:57 GMT\r\n"
-> "Server: Apache-Coyote/1.1\r\n"
-> "Pragma: no-cache\r\n"
-> "Expires: 0\r\n"
-> "Cache-Control: no-cache, no-store, must-revalidate\r\n"
-> "Strict-Transport-Security: max-age=31536000\r\n"
-> "unipay-code: 3\r\n"
-> "unibroker-code: 2\r\n"
-> "Content-Type: text/plain; charset=UTF-8\r\n"
-> "Content-Length: 714\r\n"
-> "Strict-Transport-Security: max-age=31536000\r\n"
-> "Set-Cookie: JSESSIONID=xAlQgQLYxBtHYMKjape+SxU-; Path=/; Secure; HttpOnly\r\n"
-> "Connection: close\r\n"
-> "\r\n"
reading 714 bytes...
-> ""
-> "responseType=sale&approvalCode=1843589831&providerTransactionId=&providerResponseMessage=Approved&providerAvsResponseCode=&accountNumberMasked=4***********1111&avsResponseCode=&responseCode=A01&entryModeType=M&cscResponseCode=&balance=&cycleCode=82283&entryMediumType=MC&holderVerificationModeType=&holderName=Longbob+Longsen&amount=5000&extendedAccountType=VC&warningCode=&accountType=R&transactionCode=&transactionDate=20180717&providerTransactionCode=&transactionId=654303&token=VC10000000000008591111&accountId=1804001&originalAmount=5000&providerResponseCode=&accountAccessory=0422&providerCscResponseCode=&responseMessage=Approved&currencyCode=USD&processorCode=1843589831&terminalMessage=&processorResponse="
read 714 bytes
Conn close
    )
  end

  def post_scrubbed
    %q(
opening connection to sandbox-secure.ziftpay.com:443...
opened
starting SSL for sandbox-secure.ziftpay.com:443...
SSL established
<- "POST /gates/xurl? HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: sandbox-secure.ziftpay.com\r\nContent-Length: 363\r\n\r\n"
<- "amount=5000&transactionIndustryType=RE&transactionCategoryType=B&memo=Store+Purchase&accountType=R&accountNumber=[FILTERED]&accountAccessory=0422&holderName=Longbob+Longsen&csc=[FILTERED]&street=456+My+Street&city=Ottawa&countryCode=CA&state=ON&zipCode=K1C2N6&userName=api-evtc-ms1804000&password=[FILTERED]&accountId=1804001&requestType=sale"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Tue, 17 Jul 2018 16:43:57 GMT\r\n"
-> "Server: Apache-Coyote/1.1\r\n"
-> "Pragma: no-cache\r\n"
-> "Expires: 0\r\n"
-> "Cache-Control: no-cache, no-store, must-revalidate\r\n"
-> "Strict-Transport-Security: max-age=31536000\r\n"
-> "unipay-code: 3\r\n"
-> "unibroker-code: 2\r\n"
-> "Content-Type: text/plain; charset=UTF-8\r\n"
-> "Content-Length: 714\r\n"
-> "Strict-Transport-Security: max-age=31536000\r\n"
-> "Set-Cookie: JSESSIONID=xAlQgQLYxBtHYMKjape+SxU-; Path=/; Secure; HttpOnly\r\n"
-> "Connection: close\r\n"
-> "\r\n"
reading 714 bytes...
-> ""
-> "responseType=sale&approvalCode=1843589831&providerTransactionId=&providerResponseMessage=Approved&providerAvsResponseCode=&accountNumberMasked=4***********1111&avsResponseCode=&responseCode=A01&entryModeType=M&cscResponseCode=&balance=&cycleCode=82283&entryMediumType=MC&holderVerificationModeType=&holderName=Longbob+Longsen&amount=5000&extendedAccountType=VC&warningCode=&accountType=R&transactionCode=&transactionDate=20180717&providerTransactionCode=&transactionId=654303&token=VC10000000000008591111&accountId=1804001&originalAmount=5000&providerResponseCode=&accountAccessory=0422&providerCscResponseCode=&responseMessage=Approved&currencyCode=USD&processorCode=1843589831&terminalMessage=&processorResponse="
read 714 bytes
Conn close
    )
  end

  def successful_purchase_response
    "responseType=sale&approvalCode=1016125726&providerTransactionId=&providerResponseMessage=Approved&providerAvsResponseCode=&accountNumberMasked=4***********1111&avsResponseCode=&responseCode=A01&entryModeType=M&cscResponseCode=&balance=&cycleCode=82193&entryMediumType=MC&holderVerificationModeType=&holderName=Longbob+Longsen&amount=50&extendedAccountType=VC&warningCode=&accountType=R&transactionCode=&transactionDate=20180716&providerTransactionCode=&transactionId=653613&token=VC10000000000008591111&accountId=1804001&originalAmount=50&providerResponseCode=&accountAccessory=0422&providerCscResponseCode=&responseMessage=Approved&currencyCode=USD&processorCode=1016125726&terminalMessage=&processorResponse="
  end

  def failed_purchase_response
    "responseType=sale&approvalCode=&providerTransactionId=&providerResponseMessage=Insufficient+Funds&providerAvsResponseCode=&accountNumberMasked=4***********1111&avsResponseCode=&responseCode=D03&entryModeType=M&cscResponseCode=&balance=&cycleCode=82193&entryMediumType=MC&holderVerificationModeType=&holderName=Longbob+Longsen&amount=12500&extendedAccountType=VC&warningCode=&accountType=R&transactionCode=&transactionDate=20180716&providerTransactionCode=&transactionId=653643&token=VC10000000000008591111&accountId=1804001&originalAmount=12500&providerResponseCode=&accountAccessory=0422&providerCscResponseCode=&responseMessage=Insufficient+Funds&currencyCode=USD&processorCode=&terminalMessage=&processorResponse="
  end

  def successful_authorize_response
    "responseType=sale-auth&approvalCode=336373676&providerTransactionId=&providerResponseMessage=Approved&providerAvsResponseCode=&accountNumberMasked=4***********1111&avsResponseCode=&responseCode=A01&entryModeType=M&cscResponseCode=&balance=&cycleCode=82193&entryMediumType=MC&holderVerificationModeType=&holderName=Longbob+Longsen&amount=5000&extendedAccountType=VC&warningCode=&accountType=R&transactionCode=&transactionDate=20180716&providerTransactionCode=&transactionId=653653&token=VC10000000000008591111&accountId=1804001&originalAmount=5000&providerResponseCode=&accountAccessory=0422&providerCscResponseCode=&responseMessage=Approved&currencyCode=USD&processorCode=336373676&terminalMessage=&processorResponse="
  end

  def failed_authorize_response
    "responseType=sale-auth&approvalCode=&providerTransactionId=&providerResponseMessage=Insufficient+Funds&providerAvsResponseCode=&accountNumberMasked=4***********1111&avsResponseCode=&responseCode=D03&entryModeType=M&cscResponseCode=&balance=&cycleCode=82193&entryMediumType=MC&holderVerificationModeType=&holderName=Longbob+Longsen&amount=12500&extendedAccountType=VC&warningCode=&accountType=R&transactionCode=&transactionDate=20180716&providerTransactionCode=&transactionId=653522&token=VC10000000000008591111&accountId=1804001&originalAmount=12500&providerResponseCode=&accountAccessory=0422&providerCscResponseCode=&responseMessage=Insufficient+Funds&currencyCode=USD&processorCode=&terminalMessage=&processorResponse="
  end

  def successful_capture_response
    "responseType=capture&accountId=1804001&remainingAmount=5000&providerTransactionId=&transactionCode=&cycleCode=82193&responseMessage=Approved&transactionId=653653&terminalMessage=&responseCode=A01"
  end

  def failed_capture_response
    "responseType=exception&failureCode=V28&failureMessage=Capture+Amount+value+must+be+less+than+or+equal+to+Authorization+Amount.+%5BaccountId%3D1804001%2C+requestType%3Dcapture%2C+transactionId%3D653572%2C+providerProfileCode%3D60791%2C+providerProfileType%3Dcards-realtime%2Fproxy%5D"
  end

  def successful_refund_response
    "responseType=refund&accountId=1804001&remainingAmount=0&providerTransactionId=&originalTransactionCode=&transactionCode=&cycleCode=82193&responseMessage=Void+Posted+%28Auth+Reversed%29&voidAmount=5000&transactionId=653693&terminalMessage=&responseCode=A03&processorResponse="
  end

  def failed_refund_response
    "responseType=exception&failureCode=V24&failureMessage=Referenced+Transaction+is+not+found+within+the+System+or+not+accessible+to+the+current+user."
  end

  def successful_void_response
    "responseType=void&accountId=1804001&remainingAmount=0&providerTransactionId=&transactionCode=&cycleCode=82193&responseMessage=Void+Posted+%28Auth+Reversed%29&voidAmount=5000&transactionId=653632&terminalMessage=&responseCode=A03&processorResponse=&voidReasonCode=CI"
  end

  def failed_void_response
    "responseType=exception&failureCode=V24&failureMessage=Referenced+Transaction+is+not+found+within+the+System+or+not+accessible+to+the+current+user."
  end

  def successful_verify_response
    "responseType=account-verification&approvalCode=&providerTransactionId=&providerResponseMessage=Approved&providerAvsResponseCode=&accountNumberMasked=4***********1111&avsResponseCode=&responseCode=A01&entryModeType=M&cscResponseCode=&cycleCode=82283&entryMediumType=MC&holderVerificationModeType=&holderName=Longbob+Longsen&extendedAccountType=VC&accountType=R&transactionCode=&transactionDate=20180717&providerTransactionCode=&transactionId=654283&token=VC10000000000008591111&accountId=1804001&providerResponseCode=&accountAccessory=0422&providerCscResponseCode=&responseMessage=Approved=USD&processorCode=&terminalMessage=&processorResponse="
  end

  def failed_verify_response
    "responseType=exception&failureCode=V21&failureMessage=Field%27s+accountNumber+value+is+invalid.&failedRequestType=account-verification"
  end

end
