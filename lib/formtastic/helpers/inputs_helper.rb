require 'helpers/fieldset_wrapper'
require 'helpers/file_column_detection'
require 'reflection'
require 'localized_string'

module Formtastic
  module Helpers
    
    # InputsHelper encapsulates the responsibilties of the {#inputs} and {#input} helpers at the core of the 
    # Formtastic DSL.
    #
    # {#inputs} is used to wrap a series of form items in a `<fieldset>` and `<ol>`, with each item
    # in the list containing the markup representing a single {#input}.
    #
    # {#inputs} is usually called with a block containing a series of {#input} calls:
    #
    #     <%= semantic_form_for @post do |f| %>
    #       <%= f.inputs do %>
    #         <%= f.input :title %>
    #         <%= f.input :body %>
    #       <% end %>
    #     <% end %>
    #
    # The HTML output will be something like:
    #
    #     <form class="formtastic" method="post" action="...">
    #       <fieldset>
    #         <ol>
    #           <li class="string required" id="post_title_input">
    #             <label for="post_title">Title*</label>
    #             <input type="text" name="post[title]" id="post_title" value="">
    #           </li>
    #           <li class="text required" id="post_body_input">
    #             <label for="post_title">Title*</label>
    #             <textarea name="post[body]" id="post_body"></textarea>
    #           </li>
    #         </ol>
    #       </fieldset>
    #     </form>
    #
    # It's important to note that the `semantic_form_for` and {#inputs} blocks wrap the
    # standard Rails `form_for` helper and form builder, so you have full access to every standard
    # Rails form helper, with any HTML markup and ERB syntax, allowing you to "break free" from 
    # Formtastic when it doesn't suit:
    #
    #     <%= semantic_form_for @post do |f| %>
    #       <%= f.inputs do %>
    #         <%= f.input :title %>
    #         <li>
    #           <%= f.text_area :body %>
    #         <li>
    #       <% end %>
    #     <% end %>
    #
    # There are many other syntax variations and arguments to customize your form. See the
    # full documentation of {#inputs} and {#input} for details.
    module InputsHelper
      include Formtastic::Helpers::FieldsetWrapper
      include Formtastic::Helpers::FileColumnDetection
      include Formtastic::Reflection
      include Formtastic::LocalizedString
      
      RESERVED_COLUMNS = [:created_at, :updated_at, :created_on, :updated_on, :lock_version, :version]
      
      # Returns a chunk of HTML markup for a given `method` on the form object, wrapped in
      # an `<li>` wrapper tag with appropriate `class` and `id` attribute hooks for CSS and JS.
      # In many cases, the contents of the wrapper will be as simple as a `<label>` and an `<input>`:
      #
      #     <%= f.input :title, :as => :string, :required => true %>
      #
      #     <li class="string required" id="post_title_input">
      #       <label for="post_title">Title<abbr title="Required">*</abbr></label>
      #       <input type="text" name="post[title]" value="" id="post_title">
      #     </li>
      #
      # In other cases (like a series of checkboxes for a `has_many` relationship), the wrapper may 
      # include more complex markup, like a nested `<fieldset>` with a `<legend>` and an `<ol>` of 
      # checkbox/label pairs for each choice:
      #
      #     <%= f.input :categories, :as => :check_boxes, :collection => Category.active.ordered %>
      #
      #     <li class="check_boxes" id="post_categories_input">
      #       <fieldset>
      #         <legend>Categories</legend>
      #         <ol>
      #           <li>
      #             <label><input type="checkbox" name="post[categories][1]" value="1"> Ruby</label>
      #           </li>
      #           <li>
      #             <label><input type="checkbox" name="post[categories][2]" value="2"> Rails</label>
      #           </li>
      #           <li>
      #             <label><input type="checkbox" name="post[categories][2]" value="2"> Awesome</label>
      #           </li>
      #         </ol>
      #       </fieldset>
      #     </li>
      #
      # Sensible defaults for all options are guessed by looking at the method name, database column 
      # information, association information, validation information, etc. For example, a `:string`
      # database column will map to a `:string` input, but if the method name contains 'email', will
      # map to an `:email` input instead. `belongs_to` associations will have a `:select` input, etc.
      #             
      # Formtastic supports many different styles of inputs, and you can/should override the default
      # with the `:as` option. Internally, the symbol is used to map to a protected method 
      # responsible for the details. For example, `:as => :string` will map to `string_input`, 
      # defined in a module of the same name. Detailed documentation for each input style and it's 
      # supported options is available on the `*_input` method in each module (links provided below).
      #
      # Available input styles:
      #
      # * `:boolean`      (see {Inputs::BooleanInput})
      # * `:check_boxes`  (see {Inputs::CheckBoxesInput})
      # * `:country`      (see {Inputs::CountryInput})
      # * `:datetime`     (see {Inputs::DatetimeInput})
      # * `:date`         (see {Inputs::DateInput})
      # * `:email`        (see {Inputs::EmailInput})
      # * `:hidden`       (see {Inputs::HiddenInput})
      # * `:numeric`      (see {Inputs::NumericInput})
      # * `:password`     (see {Inputs::PasswordInput})
      # * `:phone`        (see {Inputs::PhoneInput})
      # * `:radio`        (see {Inputs::RadioInput})
      # * `:search`       (see {Inputs::SearchInput})
      # * `:select`       (see {Inputs::SelectInput})
      # * `:string`       (see {Inputs::StringInput})
      # * `:text`         (see {Inputs::TextInput})
      # * `:time_zone`    (see {Inputs::TimeZoneInput})
      # * `:time`         (see {Inputs::TimeInput})
      # * `:url`          (see {Inputs::UrlInput})
      #
      # @param [Symbol] method The database column or method name on the form object that this input represents
      # @option options [Symbol] :as Override the style of input should be rendered
      # @option options [String, Symbol, Proc] :label Override the label text
      # @option options [String, Symbol, Proc] :hint Override hint text
      # @option options [Boolean] :required Optional flag to mark the input as required (or not)
      # @option options [Hash] :input_html Optional HTML attributes to be passed down to the `<input>` tag
      # @option options [Hash] :wrapper_html Optional HTML attributes to be passed down to the wrapping `<li>` tag
      #
      # Examples:
      #
      #     <% semantic_form_for @employee do |form| %>
      #       <% form.inputs do -%>
      #         <%= form.input :name, :label => "Full Name" %>
      #         <%= form.input :manager, :as => :radio %>
      #         <%= form.input :secret, :as => :password, :input_html => { :value => "xxxx" } %>
      #         <%= form.input :hired_at, :as => :date, :label => "Date Hired" %>
      #         <%= form.input :phone, :required => false, :hint => "Eg: +1 555 1234" %>
      #         <%= form.input :email %>
      #         <%= form.input :website, :as => :url, :hint => "You may wish to omit the http://" %>
      #       <% end %>
      #     <% end %>
      def input(method, options = {})
        options = options.dup # Allow options to be shared without being tainted by Formtastic
        
        options[:required] = method_required?(method) unless options.key?(:required)
        options[:as]     ||= default_input_type(method, options)
    
        html_class = [ options[:as], (options[:required] ? :required : :optional) ]
        html_class << 'error' if has_errors?(method, options)
    
        wrapper_html = options.delete(:wrapper_html) || {}
        wrapper_html[:id]  ||= generate_html_id(method)
        wrapper_html[:class] = (html_class << wrapper_html[:class]).flatten.compact.join(' ')
    
        if options[:input_html] && options[:input_html][:id]
          options[:label_html] ||= {}
          options[:label_html][:for] ||= options[:input_html][:id]
        end
    
        input_parts = (custom_inline_order[options[:as]] || inline_order).dup
        input_parts = input_parts - [:errors, :hints] if options[:as] == :hidden
    
        list_item_content = input_parts.map do |type|
          send(:"inline_#{type}_for", method, options)
        end.compact.join("\n")
    
        return template.content_tag(:li, Formtastic::Util.html_safe(list_item_content), wrapper_html)
      end
    
      # Creates an input fieldset and ol tag wrapping for use around a set of inputs.  It can be
      # called either with a block (in which you can do the usual Rails form stuff, HTML, ERB, etc),
      # or with a list of fields.  These two examples are functionally equivalent:
      #
      #   # With a block:
      #   <% semantic_form_for @post do |form| %>
      #     <% form.inputs do %>
      #       <%= form.input :title %>
      #       <%= form.input :body %>
      #     <% end %>
      #   <% end %>
      #
      #   # With a list of fields:
      #   <% semantic_form_for @post do |form| %>
      #     <%= form.inputs :title, :body %>
      #   <% end %>
      #
      #   # Output:
      #   <form ...>
      #     <fieldset class="inputs">
      #       <ol>
      #         <li class="string">...</li>
      #         <li class="text">...</li>
      #       </ol>
      #     </fieldset>
      #   </form>
      #
      # === Quick Forms
      #
      # When called without a block or a field list, an input is rendered for each column in the
      # model's database table, just like Rails' scaffolding.  You'll obviously want more control
      # than this in a production application, but it's a great way to get started, then come back
      # later to customise the form with a field list or a block of inputs.  Example:
      #
      #   <% semantic_form_for @post do |form| %>
      #     <%= form.inputs %>
      #   <% end %>
      #
      #   With a few arguments:
      #   <% semantic_form_for @post do |form| %>
      #     <%= form.inputs "Post details", :title, :body %>
      #   <% end %>
      #
      # === Options
      #
      # All options (with the exception of :name/:title) are passed down to the fieldset as HTML
      # attributes (id, class, style, etc).  If provided, the :name/:title option is passed into a
      # legend tag inside the fieldset.
      #
      #   # With a block:
      #   <% semantic_form_for @post do |form| %>
      #     <% form.inputs :name => "Create a new post", :style => "border:1px;" do %>
      #       ...
      #     <% end %>
      #   <% end %>
      #
      #   # With a list (the options must come after the field list):
      #   <% semantic_form_for @post do |form| %>
      #     <%= form.inputs :title, :body, :name => "Create a new post", :style => "border:1px;" %>
      #   <% end %>
      #
      #   # ...or the equivalent:
      #   <% semantic_form_for @post do |form| %>
      #     <%= form.inputs "Create a new post", :title, :body, :style => "border:1px;" %>
      #   <% end %>
      #
      # === It's basically a fieldset!
      #
      # Instead of hard-coding fieldsets & legends into your form to logically group related fields,
      # use inputs:
      #
      #   <% semantic_form_for @post do |f| %>
      #     <% f.inputs do %>
      #       <%= f.input :title %>
      #       <%= f.input :body %>
      #     <% end %>
      #     <% f.inputs :name => "Advanced", :id => "advanced" do %>
      #       <%= f.input :created_at %>
      #       <%= f.input :user_id, :label => "Author" %>
      #     <% end %>
      #     <% f.inputs "Extra" do %>
      #       <%= f.input :update_at %>
      #     <% end %>
      #   <% end %>
      #
      #   # Output:
      #   <form ...>
      #     <fieldset class="inputs">
      #       <ol>
      #         <li class="string">...</li>
      #         <li class="text">...</li>
      #       </ol>
      #     </fieldset>
      #     <fieldset class="inputs" id="advanced">
      #       <legend><span>Advanced</span></legend>
      #       <ol>
      #         <li class="datetime">...</li>
      #         <li class="select">...</li>
      #       </ol>
      #     </fieldset>
      #     <fieldset class="inputs">
      #       <legend><span>Extra</span></legend>
      #       <ol>
      #         <li class="datetime">...</li>
      #       </ol>
      #     </fieldset>
      #   </form>
      #
      # === Nested attributes
      #
      # As in Rails, you can use semantic_fields_for to nest attributes:
      #
      #   <% semantic_form_for @post do |form| %>
      #     <%= form.inputs :title, :body %>
      #
      #     <% form.semantic_fields_for :author, @bob do |author_form| %>
      #       <% author_form.inputs do %>
      #         <%= author_form.input :first_name, :required => false %>
      #         <%= author_form.input :last_name %>
      #       <% end %>
      #     <% end %>
      #   <% end %>
      #
      # But this does not look formtastic! This is equivalent:
      #
      #   <% semantic_form_for @post do |form| %>
      #     <%= form.inputs :title, :body %>
      #     <% form.inputs :for => [ :author, @bob ] do |author_form| %>
      #       <%= author_form.input :first_name, :required => false %>
      #       <%= author_form.input :last_name %>
      #     <% end %>
      #   <% end %>
      #
      # And if you don't need to give options to your input call, you could do it
      # in just one line:
      #
      #   <% semantic_form_for @post do |form| %>
      #     <%= form.inputs :title, :body %>
      #     <%= form.inputs :first_name, :last_name, :for => @bob %>
      #   <% end %>
      #
      # Just remember that calling inputs generates a new fieldset to wrap your
      # inputs. If you have two separate models, but, semantically, on the page
      # they are part of the same fieldset, you should use semantic_fields_for
      # instead (just as you would do with Rails' form builder).
      def inputs(*args, &block)
        title = field_set_title_from_args(*args)
        html_options = args.extract_options!
        html_options[:class] ||= "inputs"
        html_options[:name] = title
        
        if html_options[:for] # Nested form
          inputs_for_nested_attributes(*(args << html_options), &block)
        elsif block_given?
          field_set_and_list_wrapping(*(args << html_options), &block)
        else
          if @object && args.empty?
            args  = association_columns(:belongs_to)
            args += content_columns
            args -= RESERVED_COLUMNS
            args.compact!
          end
          legend = args.shift if args.first.is_a?(::String)
          contents = args.collect { |method| input(method.to_sym) }
          args.unshift(legend) if legend.present?
    
          field_set_and_list_wrapping(*((args << html_options) << contents))
        end
      end
      
      # A thin wrapper around #fields_for to set :builder => Formtastic::FormBuilder
      # for nesting forms:
      #
      #   # Example:
      #   <% semantic_form_for @post do |post| %>
      #     <% post.semantic_fields_for :author do |author| %>
      #       <% author.inputs :name %>
      #     <% end %>
      #   <% end %>
      #
      #   # Output:
      #   <form ...>
      #     <fieldset class="inputs">
      #       <ol>
      #         <li class="string"><input type='text' name='post[author][name]' id='post_author_name' /></li>
      #       </ol>
      #     </fieldset>
      #   </form>
      #
      # @private
      def semantic_fields_for(record_or_name_or_array, *args, &block)
        opts = args.extract_options!
        opts[:builder] ||= self.class
        args.push(opts)
        fields_for(record_or_name_or_array, *args, &block)
      end
      
      # Generates error messages for the given method. Errors can be shown as list,
      # as sentence or just the first error can be displayed. If :none is set, no error is shown.
      #
      # This method is also aliased as errors_on, so you can call on your custom
      # inputs as well:
      #
      #   semantic_form_for :post do |f|
      #     f.text_field(:body)
      #     f.errors_on(:body)
      #   end
      # @private
      def inline_errors_for(method, options = {}) #:nodoc:
        if render_inline_errors?
          errors = error_keys(method, options).map{|x| @object.errors[x] }.flatten.compact.uniq
          send(:"error_#{inline_errors}", [*errors], options) if errors.any?
        else
          nil
        end
      end
      alias :errors_on :inline_errors_for
      
      protected
      
      # Collects association columns (relation columns) for the current form object class.
      #
      def association_columns(*by_associations) #:nodoc:
        if @object.present? && @object.class.respond_to?(:reflections)
          @object.class.reflections.collect do |name, association_reflection|
            if by_associations.present?
              name if by_associations.include?(association_reflection.macro)
            else
              name
            end
          end.compact
        else
          []
        end
      end
      
      # Collects content columns (non-relation columns) for the current form object class.
      #
      def content_columns #:nodoc:
        model_name.constantize.content_columns.collect { |c| c.name.to_sym }.compact rescue []
      end
      
      # Deals with :for option when it's supplied to inputs methods. Additional
      # options to be passed down to :for should be supplied using :for_options
      # key.
      #
      # It should raise an error if a block with arity zero is given.
      #
      def inputs_for_nested_attributes(*args, &block) #:nodoc:
        options = args.extract_options!
        args << options.merge!(:parent => { :builder => self, :for => options[:for] })
  
        fields_for_block = if block_given?
          raise ArgumentError, 'You gave :for option with a block to inputs method, ' <<
                               'but the block does not accept any argument.' if block.arity <= 0
          lambda do |f|
            contents = f.inputs(*args){ block.call(f) }
            template.concat(contents)
          end
        else
          lambda do |f|
            contents = f.inputs(*args)
            template.concat(contents)
          end
        end
  
        fields_for_args = [options.delete(:for), options.delete(:for_options) || {}].flatten
        semantic_fields_for(*fields_for_args, &fields_for_block)
      end
      
      # Determins if the attribute (eg :title) should be considered required or not.
      #
      # * if the :required option was provided in the options hash, the true/false value will be
      #   returned immediately, allowing the view to override any guesswork that follows:
      #
      # * if the :required option isn't provided in the options hash, and the ValidationReflection
      #   plugin is installed (http://github.com/redinger/validation_reflection), or the object is
      #   an ActiveModel, true is returned
      #   if the validates_presence_of macro has been used in the class for this attribute, or false
      #   otherwise.
      #
      # * if the :required option isn't provided, and validates_presence_of can't be determined, the
      #   configuration option all_fields_required_by_default is used.
      #
      def method_required?(attribute) #:nodoc:
        attribute_sym = attribute.to_s.sub(/_id$/, '').to_sym
  
        if @object && @object.class.respond_to?(:reflect_on_validations_for)
          @object.class.reflect_on_validations_for(attribute_sym).any? do |validation|
            (validation.macro == :validates_presence_of || validation.macro == :validates_inclusion_of) &&
            validation.name == attribute_sym &&
            (validation.options.present? ? options_require_validation?(validation.options) : true)
          end
        else
          if @object && @object.class.respond_to?(:validators_on)
            !@object.class.validators_on(attribute_sym).find{|validator| (validator.kind == :presence || validator.kind == :inclusion) && (validator.options.present? ? options_require_validation?(validator.options) : true)}.nil?
          else
            all_fields_required_by_default
          end
        end
      end
      
      # Determines whether the given options evaluate to true
      def options_require_validation?(options) #nodoc
        allow_blank = options[:allow_blank]
        return !allow_blank unless allow_blank.nil?
        if_condition = !options[:if].nil?
        condition = if_condition ? options[:if] : options[:unless]
  
        condition = if condition.respond_to?(:call)
                      condition.call(@object)
                    elsif condition.is_a?(::Symbol) && @object.respond_to?(condition)
                      @object.send(condition)
                    else
                      condition
                    end
  
        if_condition ? !!condition : !condition
      end
      
      # For methods that have a database column, take a best guess as to what the input method
      # should be.  In most cases, it will just return the column type (eg :string), but for special
      # cases it will simplify (like the case of :integer, :float & :decimal to :numeric), or do
      # something different (like :password and :select).
      #
      # If there is no column for the method (eg "virtual columns" with an attr_accessor), the
      # default is a :string, a similar behaviour to Rails' scaffolding.
      #
      def default_input_type(method, options = {}) #:nodoc:
        if column = column_for(method)
          # Special cases where the column type doesn't map to an input method.
          case column.type
          when :string
            return :password  if method.to_s =~ /password/
            return :country   if method.to_s =~ /country$/
            return :time_zone if method.to_s =~ /time_zone/
            return :email     if method.to_s =~ /email/
            return :url       if method.to_s =~ /^url$|^website$|_url$/
            return :phone     if method.to_s =~ /(phone|fax)/
            return :search    if method.to_s =~ /^search$/
          when :integer
            return :select    if reflection_for(method)
            return :numeric
          when :float, :decimal
            return :numeric
          when :timestamp
            return :datetime
          end
  
          # Try look for hints in options hash. Quite common senario: Enum keys stored as string in the database.
          return :select    if column.type == :string && options.key?(:collection)
          # Try 3: Assume the input name will be the same as the column type (e.g. string_input).
          return column.type
        else
          if @object
            return :select  if reflection_for(method)
  
            return :file    if is_file?(method, options)
          end
  
          return :select    if options.key?(:collection)
          return :password  if method.to_s =~ /password/
          return :string
        end
      end
      
      # Get a column object for a specified attribute method - if possible.
      #
      def column_for(method) #:nodoc:
        @object.column_for_attribute(method) if @object.respond_to?(:column_for_attribute)
      end
      
      # Generates an input for the given method using the type supplied with :as.
      def inline_input_for(method, options)
        send(:"#{options.delete(:as)}_input", method, options)
      end
  
      # Generates hints for the given method using the text supplied in :hint.
      #
      def inline_hints_for(method, options) #:nodoc:
        options[:hint] = localized_string(method, options[:hint], :hint)
        return if options[:hint].blank? or options[:hint].kind_of? Hash
        hint_class = options[:hint_class] || default_hint_class
        template.content_tag(:p, Formtastic::Util.html_safe(options[:hint]), :class => hint_class)
      end
      
      # Creates an error sentence by calling to_sentence on the errors array.
      #
      def error_sentence(errors, options = {}) #:nodoc:
        error_class = options[:error_class] || default_inline_error_class
        template.content_tag(:p, Formtastic::Util.html_safe(errors.to_sentence.untaint), :class => error_class)
      end
  
      # Creates an error li list.
      #
      def error_list(errors, options = {}) #:nodoc:
        error_class = options[:error_class] || default_error_list_class
        list_elements = []
        errors.each do |error|
          list_elements <<  template.content_tag(:li, Formtastic::Util.html_safe(error.untaint))
        end
        template.content_tag(:ul, Formtastic::Util.html_safe(list_elements.join("\n")), :class => error_class)
      end
  
      # Creates an error sentence containing only the first error
      #
      def error_first(errors, options = {}) #:nodoc:
        error_class = options[:error_class] || default_inline_error_class
        template.content_tag(:p, Formtastic::Util.html_safe(errors.first.untaint), :class => error_class)
      end
      
      def field_set_title_from_args(*args) #:nodoc:
        options = args.extract_options!
        options[:name] ||= options.delete(:title)
        title = options[:name]
  
        if title.blank?
          valid_name_classes = [::String, ::Symbol]
          valid_name_classes.delete(::Symbol) if !block_given? && (args.first.is_a?(::Symbol) && content_columns.include?(args.first))
          title = args.shift if valid_name_classes.any? { |valid_name_class| args.first.is_a?(valid_name_class) }
        end
        title = localized_string(title, title, :title) if title.is_a?(::Symbol)
        title
      end
      
    end
  end
end