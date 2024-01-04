require 'mail'

module Manifest
  module MailFormat
    extend self

    def generate_message(sender:, to_addresses:, email_subject:, html_content:, text_content: '')
      Mail.new do |message|
        message.from = sender 
        message.to = to_addresses
        message.subject = email_subject
        message.content_type = 'multipart/mixed'
        message.part(content_type: 'multipart/related') do |related|
          related.part(content_type: 'multipart/alternative') do |alternative|
            alternative.part(
              content_type: 'text/plain',
              body: text_content
            )
            alternative.part(
              content_type: 'text/html; charset=UTF-8',
              body: html_content
            )
          end

        end
      end
    end
  end
end