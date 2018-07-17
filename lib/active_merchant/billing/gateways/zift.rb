module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ZiftGateway < Gateway
      self.test_url = 'https://sandbox-secure.ziftpay.com/gates/xurl?'
      self.live_url = 'https://secure.ziftpay.com/gates/xurl?'

      self.supported_countries = [
          "AU", "CA", "US"]

      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.money_format = :cents

      self.homepage_url = 'http://ziftpay.com/'
      self.display_name = 'Zift'

      CURRENCY_CODES = {
          'AUD' => '036', 'CAD' => '124', 'USD' => '840'
      }

      ACCOUNT_TYPE_BRANDED_CREDIT_CARD = 'R'
      ACCOUNT_TYPE_BRANDED_DEBIT_CHECKING_CARD = 'E'
      ACCOUNT_TYPE_BRANDED_DEBIT_SAVINGS_CARD = 'V'
      ACCOUNT_TYPE_BANK_SACINGS_ACCOUNT = 'S'
      ACCOUNT_TYPE_BANK_CHECKING_ACCOUNT = 'C'

      TRANSACTION_INDUSTRY_TYPE_DIRECT_MARKETING = 'DB'
      TRANSACTION_INDUSTRY_TYPE_ECOMMERCE = 'EC'
      TRANSACTION_INDUSTRY_TYPE_RETAIL = 'RE'
      TRANSACTION_INDUSTRY_TYPE_RESTAURANT = 'RS'
      TRANSACTION_INDUSTRY_TYPE_LODGING = 'LD'
      TRANSACTION_INDUSTRY_TYPE_CAR_RENTAL = 'PT'

      TRANSACTION_CATEGORY_TYPE_BILL_PAYMENT = 'B'
      TRANSACTION_CATEGORY_TYPE_RECURRING = 'R'
      TRANSACTION_CATEGORY_TYPE_INSTALLMENT = 'I'
      TRANSACTION_CATEGORY_TYPE_HEALTHCARE = 'H'

      STANDARD_ERROR_CODE_MAPPING = {}

      SUCCESS_CODES = ["A01", "A02", "A03", "A04", "A05", "A06", "A07", "A08", "A09", "A10"]

      def initialize(options={})
        requires!(options, :userName, :password, :accountId)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_customer_data(post, options)

        commit('sale', post, SUCCESS_CODES)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_customer_data(post, options)

        commit('sale-auth', post, SUCCESS_CODES)
      end

      def capture(money, authorization, options={})
        post = { transactionId: authorization }
        add_invoice(post, money, options)
        commit("capture", post, SUCCESS_CODES)
      end

      def refund(money, authorization, options={})
        post = { transactionId: authorization }
        add_invoice(post, money, options)
        commit("refund", post, SUCCESS_CODES)
      end

      def void(authorization, options={})
        post = { transactionId: authorization }
        commit("void", post, SUCCESS_CODES)
      end

      def verify(payment, options={})
        post = {}
        add_payment(post, payment)
        add_customer_data(post, options)
        post[:transactionIndustryType] = TRANSACTION_INDUSTRY_TYPE_RETAIL
        commit('account-verification', post, SUCCESS_CODES)
      end

      # def credit(money, payment, options = {})
      #   post = {}
      #   add_invoice(post, money, options)
      #   add_payment(post, payment)
      #   add_customer_data(post, options)
      #   commit('credit', post, SUCCESS_CODES)
      # end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
            gsub(%r((accountNumber=)\d+), '\1[FILTERED]\2').
            gsub(%r((password=)[\w]+), '\1[FILTERED]\2').
            gsub(%r((csc=)\d+), '\1[FILTERED]\2')
      end

      private

      def add_customer_data(post, options)
        if(billing_address = options[:billing_address] || options[:address])
          post[:street] = billing_address[:address1]
          post[:city] = billing_address[:city]
          post[:countryCode] = billing_address[:country]
          post[:state] = billing_address[:state]
          post[:zipCode] = billing_address[:zip]
        end
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:transactionIndustryType] = TRANSACTION_INDUSTRY_TYPE_RETAIL
        post[:transactionCategoryType] = TRANSACTION_CATEGORY_TYPE_BILL_PAYMENT
        # post[:transactionModeType] = 'P'

        post[:taxAmount] = options[:tax] if options[:tax].present?
        # currency = (options[:currency] || currency(money))
        # post[:tran_currency] = CURRENCY_CODES[currency] if currency.present?
        post[:orderCode] = options[:order_id] if options[:order_id].present?
        cust_id = options[:customer_id] || options[:customer]
        post[:customerAccountCode] = cust_id if cust_id.present?
        post[:memo] = options[:description] if options[:description].present?
      end

      def add_payment(post, payment)
        # Not sure how to get the correct account type
        post[:accountType] = ACCOUNT_TYPE_BRANDED_CREDIT_CARD
        post[:accountNumber] = payment.number
        post[:accountAccessory] = exp_date(payment)
        post[:holderName] = payment.name
        post[:csc] = payment.verification_value unless payment.verification_value.blank?
      end

      def exp_date(payment)
        "#{format(payment.month, :two_digits)}#{format(payment.year, :two_digits)}"
      end

      def parse(response)
        Hash[
            response.split('&').map do |x|
              key, val = x.split('=', 2)
              [key.split('.').last, CGI.unescape(val)]
            end
        ]
      end

      def commit(action, parameters, success_codes)
        url = "#{(test? ? test_url : live_url)}"
        parameters = parameters.merge(@options).merge({
            requestType: action
        })

        begin
          raw_response = ssl_post(url, post_data(action, parameters), headers)
          response = parse(raw_response)
        rescue ResponseError => e
          raise unless(e.response.code.to_s =~ /4\d\d/)
          response = parse(e.response.body)
        end

        succeeded = success_from(response, success_codes)

        Response.new(
            succeeded,
            message_from(succeeded, response),
            response,
            authorization: authorization_from(response),
            avs_result: AVSResult.new(code: response["auth_avs_result"]),
            cvv_result: CVVResult.new(response["auth_cvv2_result"]),
            test: test?,
            error_code: error_code_from(response, response["responseCode"])
        )
      end

      def headers
        { "Content-Type"  => "application/x-www-form-urlencoded" }
      end

      def success_from(response, success_codes)
        response["responseCode"].present? && success_codes.include?(response["responseCode"])
      end

      def message_from(succeeded, response)
        if succeeded
          "Succeeded"
        else
          response["responseMessage"] || response["failureMessage"]
        end
      end

      def authorization_from(response)
        response["transactionId"]
      end

      def post_data(action, parameters = {})
        # parameters[:developer_id] = "ActiveMerchant"
        URI.encode_www_form(parameters)
      end

      def error_code_from(response, successful_text)
        unless success_from(response, successful_text)
          response["responseCode"]
        end
      end
    end
  end
end

