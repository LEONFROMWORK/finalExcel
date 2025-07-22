# frozen_string_literal: true

require 'httparty'

class PythonServiceClient
  include HTTParty
  
  def initialize
    @base_uri = ENV['PYTHON_SERVICE_URL'] || 'http://localhost:8000'
  end
  
  def analyze_excel(file_path, user_query = nil)
    File.open(file_path, 'rb') do |file|
      options = {
        multipart: true,
        body: {
          file: file,
          user_query: user_query
        }.compact
      }
      
      response = self.class.post("#{@base_uri}/api/v1/excel/analyze", options)
      handle_response(response)
    end
  end
  
  def modify_excel(file_url, modifications)
    options = {
      headers: { 'Content-Type' => 'application/json' },
      body: {
        file_url: file_url,
        modifications: modifications
      }.to_json
    }
    
    response = self.class.post("#{@base_uri}/api/v1/excel-modifications/modify", options)
    handle_response(response)
  end
  
  def analyze_vba(file_path)
    File.open(file_path, 'rb') do |file|
      options = {
        multipart: true,
        body: { file: file }
      }
      
      response = self.class.post("#{@base_uri}/api/v1/vba/analyze-vba", options)
      handle_response(response)
    end
  end
  
  def analyze_image(image_path, analysis_type = 'auto')
    File.open(image_path, 'rb') do |file|
      options = {
        multipart: true,
        body: {
          file: file,
          analysis_type: analysis_type
        }
      }
      
      response = self.class.post("#{@base_uri}/api/v1/image/analyze-image", options)
      handle_response(response)
    end
  end
  
  def create_from_template(template_id, customizations = {})
    options = {
      headers: { 'Content-Type' => 'application/json' },
      body: {
        template_id: template_id,
        customizations: customizations
      }.to_json
    }
    
    response = self.class.post("#{@base_uri}/api/v1/excel-modifications/create-from-template", options)
    handle_response(response)
  end
  
  def create_from_ai(description, requirements = [])
    options = {
      headers: { 'Content-Type' => 'application/json' },
      body: {
        description: description,
        requirements: requirements
      }.to_json
    }
    
    response = self.class.post("#{@base_uri}/api/v1/excel-modifications/create-from-ai", options)
    handle_response(response)
  end
  
  def images_to_excel(images, merge_strategy = 'separate_sheets')
    form_data = { merge_strategy: merge_strategy }
    
    # Add each image to form data
    images.each_with_index do |image_path, index|
      File.open(image_path, 'rb') do |file|
        form_data["files[#{index}]"] = file
      end
    end
    
    options = {
      multipart: true,
      body: form_data
    }
    
    response = self.class.post("#{@base_uri}/api/v1/image/images-to-excel", options)
    handle_response(response)
  end
  
  def health_check
    response = self.class.get("#{@base_uri}/api/v1/health")
    response.success? && response.parsed_response['status'] == 'healthy'
  rescue StandardError
    false
  end
  
  private
  
  def handle_response(response)
    if response.success?
      response.parsed_response
    else
      Rails.logger.error "Python service error: #{response.code} - #{response.body}"
      raise "Python service error: #{response.code}"
    end
  end
end