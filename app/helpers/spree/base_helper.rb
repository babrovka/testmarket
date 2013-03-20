module Spree
  module BaseHelper
    
    def availability_status(status)
      
      if status == 1
        content_tag(:span, t(:on_hand), :class => "on_hand")
      elsif status == 2
        content_tag(:span, t(:ready_for_order), :class => "ready_for_order") 
      elsif status == 3
        content_tag(:span, t(:is_waited), :class => "is_waited")      
      else
        content_tag(:span, t(:no_available), :class => "no_available") 
      end      
         
    end
    
    def link_to_submit(*args, &block)
      link_to_function (block_given? ? capture(&block) : args[0]), "$(this).closest('form').submit()", args.extract_options!
    end

    # Defined because Rails' current_page? helper is not working when Spree is mounted at root.
    def current_spree_page?(url)
      path = request.fullpath.gsub(/^\/\//, '/')
      if url.is_a?(String)
        return path == url
      elsif url.is_a?(Hash)
        return path == spree.url_for(url)
      end
      return false
    end

    def link_to_cart(text = nil)
      return "" if current_spree_page?(cart_path)

      text = text ? h(text) : t('cart')
      css_class = nil

      if current_order.nil? or current_order.line_items.empty?
        text = "#{text}: (#{t('empty')})"
        css_class = 'empty'
      else
        text = "#{text}: (#{current_order.item_count})  <span class='amount'>#{order_subtotal(current_order)}</span>".html_safe
        css_class = 'full'
      end

      link_to text, cart_path, :class => css_class
    end

    def order_subtotal(order, options={})
      options.assert_valid_keys(:format_as_currency, :show_vat_text)
      options.reverse_merge! :format_as_currency => true, :show_vat_text => true

      amount =  order.total

      options.delete(:format_as_currency) ? number_to_currency(amount) : amount
    end

    def todays_short_date
      utc_to_local(Time.now.utc).to_ordinalized_s(:stub)
    end

    def yesterdays_short_date
      utc_to_local(Time.now.utc.yesterday).to_ordinalized_s(:stub)
    end

    # human readable list of variant options
    def variant_options(v, allow_back_orders = Spree::Config[:allow_backorders], include_style = true)
      list = v.options_text

      # We shouldn't show out of stock if the product is infact in stock
      # or when we're not allowing backorders.
      unless (allow_back_orders || v.in_stock?)
        list = if include_style
          content_tag(:span, "(#{t(:out_of_stock)}) #{list}", :class => 'out-of-stock')
        else
          "#{t(:out_of_stock)} #{list}"
        end
      end

      list
    end

    def meta_data_tags
      object = instance_variable_get('@'+controller_name.singularize)
      meta = {}

      if object.kind_of? ActiveRecord::Base
        meta[:keywords] = object.meta_keywords if object[:meta_keywords].present?
        meta[:description] = object.meta_description if object[:meta_description].present?
      end

      if meta[:description].blank? && object.kind_of?(Spree::Product)
        meta[:description] = strip_tags(object.description)
      end

      meta.reverse_merge!({
        :keywords => Spree::Config[:default_meta_keywords],
        :description => Spree::Config[:default_meta_description]
      })

      meta.map do |name, content|
        tag('meta', :name => name, :content => content)
      end.join("\n")
    end

    def body_class
      @body_class ||= content_for?(:sidebar) ? 'two-col' : 'one-col'
      @body_class
    end

    def logo(image_path=Spree::Config[:logo])
      link_to image_tag(image_path), root_path
    end

    def flash_messages(opts = {})
      opts[:ignore_types] = [:commerce_tracking].concat(opts[:ignore_types] || [])

      flash.each do |msg_type, text|
        unless opts[:ignore_types].include?(msg_type)
          concat(content_tag :div, text, :class => "flash #{msg_type}")
        end
      end
      nil
    end

    def breadcrumbs(taxon, separator="&nbsp;&raquo;&nbsp;")
      return "" if current_page?("/") || taxon.nil?
      separator = raw(separator)
      crumbs = []
      if taxon
        crumbs << taxon.ancestors.collect { |ancestor| content_tag(:li, link_to(ancestor.name , seo_url(ancestor)) + separator) } unless taxon.ancestors.empty?
        crumbs << content_tag(:li, content_tag(:span, link_to(taxon.name , seo_url(taxon))))
      else
        crumbs << content_tag(:li, content_tag(:span, t(:products)))
      end
      crumb_list = content_tag(:ul, raw(crumbs.flatten.map{|li| li.mb_chars}.join), :class => 'inline')
      content_tag(:nav, crumb_list, :id => 'breadcrumbs')
    end

    def taxons_tree(root_taxon, current_taxon, max_level = 1, is_root = true)
          return '' if max_level < 1 || root_taxon.children.empty?
          content_tag :ul do
            root_taxon.children.map do |taxon|
              css_class = (current_taxon && current_taxon.self_and_ancestors.include?(taxon)) ? 'active' : nil
              content_tag :li do
                if is_root
                  link_to(content_tag(:span, taxon.name), seo_url(taxon), :class => css_class) + taxons_tree(taxon, current_taxon, max_level - 1, false)
                else
                  link_to(taxon.name, seo_url(taxon), :class => css_class) + taxons_tree(taxon, current_taxon, max_level - 1, false)
                end
              end
            end.join("\n").html_safe
          end
        end

    def available_countries
      countries = Zone.find_by_name(Spree::Config[:checkout_zone]).try(:country_list) || Country.all
      countries.collect do |c|
        c.name = I18n.t(c.iso, :scope => 'countries', :default => c.name)
        c
      end.sort{ |a,b| a.name <=> b.name }
    end

    def format_price(price, options={})
      options.assert_valid_keys(:show_vat_text)
      formatted_price = number_to_currency price
      if options[:show_vat_text]
        I18n.t(:price_with_vat_included, :price => formatted_price)
      else
        formatted_price
      end
    end

    # generates nested url to product based on supplied taxon
    def seo_url(taxon, product = nil)
      return spree.nested_taxons_path(taxon.permalink) if product.nil?
      warn "DEPRECATION: the /t/taxon-permalink/p/product-permalink urls are "+
        "not used anymore. Use product_url instead. (called from #{caller[0]})"
      return product_url(product)
    end

    def current_orders_product_count
      if current_order.blank? || current_order.item_count < 1
        return 0
      else
        return current_order.item_count
      end
    end

    def gem_available?(name)
       Gem::Specification.find_by_name(name)
    rescue Gem::LoadError
       false
    rescue
       Gem.available?(name)
    end

    def method_missing(method_name, *args, &block)
      if image_style = image_style_from_method_name(method_name)
        define_image_method(image_style)
        self.send(method_name, *args)
      else
        super
      end
    end

    private

    # Returns style of image or nil
    def image_style_from_method_name(method_name)
      if style = method_name.to_s.sub(/_image$/, '')
        possible_styles = Spree::Image.attachment_definitions[:attachment][:styles]
        style if style.in? possible_styles.with_indifferent_access
      end
    end

    def define_image_method(style)
      self.class.send :define_method, "#{style}_image" do |product, *options|
        options = options.first || {}
        if product.images.empty?
          image_tag "noimage/#{style}.png", options
        else
          image = product.images.first
          options.reverse_merge! :alt => image.alt.blank? ? product.name : image.alt
          image_tag image.attachment.url(style), options
        end
      end
    end

  end
end
