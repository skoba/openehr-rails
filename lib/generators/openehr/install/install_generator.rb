module OpenEHR
  module Generators
    class InstallGenerator < ::Rails::Generators::Base

      desc <<DESC
Description: 
  setup openEHR environment with archetype directory.
DESC
      
      def self.source_root
        @source_root ||= File.dirname(__FILE__, 'templates')
      end

      def create_archetype_directory
        empty_directory 'app/archetypes'
      end

      def copy_i18n
        template 'i18n.rb', 'config/initializer/i18n.rb'
      end

      def inject_locale_settings
        inject_into_class "app/controllers/application_controller.rb", ApplicationController do
<<INCLUDE
  before_filter :set_i18n_locale_from_params

  private
  def set_i18n_locale_from_params
    if params[:locale]
      if I18n.avaiable_locales.include? params[:locale].to_sym
        I18n.locale = params[:locale]
      else
        flash.now[:notice] = 
          "#{params[:locale]} transaction not available"
        logger.error flash.now[:notice]
      end
    end
  end

  def default_url_options
    { locale: I18n.locale }
  end
INCLUDE
        end
      end

      def inject_locale_switcher
        inject_into_file ""
      end
    end
  end
end
