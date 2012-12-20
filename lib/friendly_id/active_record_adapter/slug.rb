# A Slug is a unique, human-friendly identifier for an ActiveRecord.
class Slug < ::ActiveRecord::Base
  attr_writer :sluggable
  attr_accessible :name, :scope, :sluggable, :sequence, :locale
  def self.named_scope(*args, &block) scope(*args, &block) end if FriendlyId.on_ar3?
  table_name = "slugs"
  before_save :enable_name_reversion, :set_sequence
  validate :validate_name
  named_scope :similar_to, lambda {|slug| {:conditions => {
        :name           => slug.name,
        :scope          => slug.scope,
        :sluggable_type => slug.sluggable_type
      }.merge(({:locale => slug.locale} if slug.respond_to?(:locale)) || {}),
      :order => "sequence ASC"
    }
  }

  def sluggable
    sluggable_id && !@sluggable and begin
      klass = sluggable_type.constantize
      klass.send(:with_exclusive_scope) do
        @sluggable = klass.find(sluggable_id.to_i)
      end
    end
    @sluggable
  end

  # Whether this slug is the most recent of its owner's slugs.
  def current?
    sluggable.slug == self
  end

  def outdated?
    !current?
  end

  def to_friendly_id
    sequence > 1 ? friendly_id_with_sequence : name
  end

  # Raise a FriendlyId::SlugGenerationError if the slug name is blank.
  def validate_name
    if name.blank?
      raise FriendlyId::BlankError.new("slug.name can not be blank.")
    end
  end

  private

  # If we're renaming back to a previously used friendly_id, delete the
  # slug so that we can recycle the name without having to use a sequence.
  def enable_name_reversion
    slugs = sluggable.slugs.where(:name => name).where(:scope => scope)
    slugs = slugs.where(:locale => locale) if sluggable.friendly_id_config.class.locales_used?
    slugs.each(&:destroy) unless slugs.empty?
  end

  def friendly_id_with_sequence
    "#{name}#{separator}#{sequence}"
  end

  def similar_to_other_slugs?
    !similar_slugs.empty?
  end

  def similar_slugs
    self.class.similar_to(self)
  end

  def separator
    sluggable.friendly_id_config.sequence_separator
  end

  def set_sequence
    return unless new_record?
    self.sequence = similar_slugs.last.sequence.succ if similar_to_other_slugs?
  end

end
