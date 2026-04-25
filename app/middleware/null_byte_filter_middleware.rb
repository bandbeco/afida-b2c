# frozen_string_literal: true

class NullByteFilterMiddleware
  NULL_BYTE = "\x00"
  ENCODED_NULL_BYTE = "%00"

  def initialize(app)
    @app = app
  end

  def call(env)
    if null_byte_in_request?(env)
      return [ 400, { "Content-Type" => "text/plain" }, [ "Bad Request" ] ]
    end

    @app.call(env)
  end

  private

  def null_byte_in_request?(env)
    return true if contains_null_byte?(env["PATH_INFO"])
    return true if contains_null_byte?(env["QUERY_STRING"])

    if form_encoded_body?(env)
      body = read_body(env)
      return true if contains_null_byte?(body)
    end

    false
  end

  def contains_null_byte?(string)
    return false if string.nil?
    string.include?(NULL_BYTE) || string.include?(ENCODED_NULL_BYTE)
  end

  def form_encoded_body?(env)
    content_type = env["CONTENT_TYPE"].to_s
    content_type.start_with?("application/x-www-form-urlencoded")
  end

  def read_body(env)
    input = env["rack.input"]
    return nil unless input

    body = input.read
    input.rewind if input.respond_to?(:rewind)
    body
  end
end
