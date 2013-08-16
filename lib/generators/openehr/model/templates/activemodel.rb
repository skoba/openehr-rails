require 'securerandom'
class <%= model_class_name %>
  include ActiveModel::Model

  def self.create(attributes = {})
    <%= model_class_name %>.new(attributes)
  end

  def self.all
    Archetype.where(archetypeid: '<%= archetype_name %>').to_a.map do |archetype|
      <%= model_class_name %>.new(archetype: archetype)
    end
  end

  def self.find(id)
    <%= model_class_name %>.new(archetype: Archetype.find(id))
  end

  def self.build(params)
    <%= model_class_name %>.new(params)
  end
  
  def save
    archetype.rms.inject(archetype.save, :&) {|rm| rm.save}
  end

  def persisted?
    archetype.persisted?
  end

  def destroy
    archetype.destroy
  end
  
  def update(attributes)
    self.attributes=attributes
  end

  def attributes=(attributes)
    attributes.each do |k, v|
       send("#{k}=", v )
    end
  end

  def id
    archetype.id
  end

  def id=(id)
    self.archetype = Archetype.find(id)
  end

  def archetype
    @archetype ||= Archetype.new(archetypeid: '<%= archetype_name %>', uid: SecureRandom.uuid)
  end

  def archetype=(archetype)
    @archetype = archetype
  end

<%= add_data_component(archetype.definition) %>
  private
  def confat(node_id, path)
    archetype.rms.find_by(:node_id => node_id) ||
      archetype.rms.build(:node_id => node_id, :path => path, :uid => SecureRandom.uuid)
  end

  def translate(term)
    I18n.translate("<%= controller_name %>.index.#{term}")
  end
end
