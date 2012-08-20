require 'google_places/review'

module GooglePlaces
  class Spot
    attr_accessor :lat, :lng, :name, :icon, :reference, :vicinity, :types, :id, :formatted_phone_number, :international_phone_number, :formatted_address, :address_components, :street_number, :street, :city, :region, :postal_code, :country, :rating, :url, :cid, :website, :reviews, :rankby

    def self.list(lat, lng, api_key, options = {})
      exclude = options[:exclude] || []
      exclude = [exclude] unless exclude.is_a?(Array)

      # Required Google Places parameters
      params = {
        :key => api_key,
        :location => Location.new(lat, lng).format,
        :sensor => !!options[:sensor],
      }

      if options[:rankby].to_s == 'distance'
        # Note that radius must not be included if rankby=distance
      else
        params[:radius] = options[:radius] || 200 # meters
      end

      # Optional Google Places parameters
      [:keyword, :language, :name, :rankby, :pagetoken].each do |optname|
        params[optname] = options[optname] if options[optname]
      end

      # Accept Types as a string or array
      types  = options[:types]
      if types
        types = (types.is_a?(Array) ? types.join('|') : types)
        params.merge! :types => types
      end

      # Finally, our options
      params[:retry_options] = options[:retry_options] || {}

      response = Request.spots(params)
      response['results'].map do |result|
        self.new(result) if (result['types'] & exclude) == []
      end.compact
    end

    def self.find(reference, api_key, options = {})
      sensor = options.delete(:sensor) || false
      language  = options.delete(:language)
      retry_options = options.delete(:retry_options) || {}

      response = Request.spot(
        :reference => reference,
        :sensor => sensor,
        :key => api_key,
        :language => language,
        :retry_options => retry_options
      )

      self.new(response['result'])
    end

    def self.list_by_query(query, api_key, options)
      if options.has_key?(:lat) && options.has_key?(:lng)
        with_location = true
      else
        with_location = false
      end

      if options.has_key?(:radius)
        with_radius = true
      else
        with_radius = false
      end

      query = query
      sensor = options.delete(:sensor) || false
      location = Location.new(options.delete(:lat), options.delete(:lng)) if with_location
      radius = options.delete(:radius) if with_radius
      language = options.delete(:language)
      types = options.delete(:types)
      exclude = options.delete(:exclude) || []
      retry_options = options.delete(:retry_options) || {}

      exclude = [exclude] unless exclude.is_a?(Array)

      options = {
        :query => query,
        :sensor => sensor,
        :key => api_key,
        :language => language,
        :retry_options => retry_options
      }

      options[:location] = location.format if with_location
      options[:radius] = radius if with_radius

      # Accept Types as a string or array
      if types
        types = (types.is_a?(Array) ? types.join('|') : types)
        options.merge!(:types => types)
      end

      response = Request.spots_by_query(options)
      response['results'].map do |result|
        self.new(result) if (result['types'] & exclude) == []
      end.compact
    end

    def initialize(json_result_object)
      @reference                  = json_result_object['reference']
      @vicinity                   = json_result_object['vicinity']
      @lat                        = json_result_object['geometry']['location']['lat']
      @lng                        = json_result_object['geometry']['location']['lng']
      @name                       = json_result_object['name']
      @icon                       = json_result_object['icon']
      @types                      = json_result_object['types']
      @id                         = json_result_object['id']
      @formatted_phone_number     = json_result_object['formatted_phone_number']
      @international_phone_number = json_result_object['international_phone_number']
      @formatted_address          = json_result_object['formatted_address']
      @address_components         = json_result_object['address_components']
      @street_number              = address_component(:street_number, 'short_name')
      @street                     = address_component(:route, 'long_name')
      @city                       = address_component(:locality, 'long_name')
      @region                     = address_component(:administrative_area_level_1, 'long_name')
      @postal_code                = address_component(:postal_code, 'long_name')
      @country                    = address_component(:country, 'long_name')
      @rating                     = json_result_object['rating']
      @url                        = json_result_object['url']
      @cid                        = json_result_object['url'].to_i
      @website                    = json_result_object['website']
      @reviews                    = reviews_component(json_result_object['reviews'])
      @rankby                     = json_result_object['rankby']
    end

    def address_component(address_component_type, address_component_length)
      if component = address_components_of_type(address_component_type)
        component.first[address_component_length] unless component.first.nil?
      end
    end

    def address_components_of_type(type)
      @address_components.select{ |c| c['types'].include?(type.to_s) } unless @address_components.nil?
    end

    def reviews_component(json_reviews)
      if json_reviews
        json_reviews.map { |r|
          Review.new(
              r['aspects'].empty? ? nil : r['aspects'][0]['rating'],
              r['aspects'].empty? ? nil : r['aspects'][0]['type'],
              r['author_name'],
              r['author_url'],
              r['text'],
              r['time'].to_i
          )
        }
      else []
      end
    end

  end
end
