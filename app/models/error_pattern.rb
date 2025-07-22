# frozen_string_literal: true

class ErrorPattern < ApplicationRecord
  # Associations
  belongs_to :created_by, class_name: "User"
  belongs_to :approved_by, class_name: "User", optional: true
  has_many :pattern_usages, class_name: "ErrorPatternUsage", dependent: :destroy

  # PostgreSQL already handles array and jsonb types natively
  # No need for serialize directives

  # Validations
  validates :question, presence: true, length: { minimum: 10 }
  validates :answer, presence: true, length: { minimum: 20 }
  validates :error_type, presence: true
  validates :category, presence: true
  validates :confidence, numericality: { in: 0..1 }

  # Scopes
  scope :approved, -> { where(approved: true) }
  scope :pending, -> { where(approved: false) }
  scope :auto_generated, -> { where(auto_generated: true) }
  scope :manual, -> { where(auto_generated: false) }
  scope :by_type, ->(type) { where(error_type: type) }
  scope :by_category, ->(category) { where(category: category) }
  scope :by_domain, ->(domain) { where(domain: domain) }
  scope :high_confidence, -> { where("confidence >= ?", 0.8) }
  scope :frequently_used, -> { where("usage_count > ?", 10) }

  # Enums
  enum :category, {
    error_pattern: 0,
    data_type_pattern: 1,
    compound_pattern: 2,
    version_pattern: 3,
    domain_pattern: 4,
    variation: 5,
    edge_case: 6
  }

  enum :error_type, {
    ref_error: 0,      # #REF!
    value_error: 1,    # #VALUE!
    div_zero: 2,       # #DIV/0!
    na_error: 3,       # #N/A
    name_error: 4,     # #NAME?
    null_error: 5,     # #NULL!
    num_error: 6,      # #NUM!
    circular_reference: 7,
    data_type_mismatch: 8,
    performance_issue: 9,
    compatibility_issue: 10,
    other: 11
  }

  # Callbacks
  before_save :normalize_tags
  after_create :sync_to_knowledge_base
  after_update :update_knowledge_base

  # Instance methods
  def approve!(user)
    update!(
      approved: true,
      approved_by: user,
      approved_at: Time.current
    )
  end

  def reject!(user, reason = nil)
    update!(
      approved: false,
      approved_by: user,
      approved_at: Time.current,
      metadata: metadata.merge(rejection_reason: reason)
    )
  end

  def record_usage!(user = nil, context = {})
    increment!(:usage_count)

    pattern_usages.create!(
      user: user,
      context: context,
      used_at: Time.current
    )
  end

  def usage_statistics
    {
      total_uses: usage_count,
      unique_users: pattern_usages.distinct.count(:user_id),
      recent_uses: pattern_usages.where("created_at > ?", 7.days.ago).count,
      contexts: pattern_usages.group(:context).count
    }
  end

  def effectiveness_score
    # 효과성 점수 계산
    base_score = confidence * 100

    # 사용 빈도 보너스
    usage_bonus = [ usage_count * 0.1, 20 ].min

    # 승인 보너스
    approval_bonus = approved? ? 10 : 0

    # 최신성 보너스 (30일 이내 생성)
    recency_bonus = created_at > 30.days.ago ? 5 : 0

    [ base_score + usage_bonus + approval_bonus + recency_bonus, 100 ].min
  end

  def similar_patterns(limit = 5)
    # 유사 패턴 찾기
    self.class.where.not(id: id)
               .where(error_type: error_type)
               .where("confidence >= ?", confidence - 0.1)
               .limit(limit)
  end

  def to_qa_pair
    {
      question: question,
      answer: answer,
      source: "error_pattern_#{id}",
      metadata: {
        error_type: error_type,
        category: category,
        domain: domain,
        tags: tags,
        confidence: confidence
      }
    }
  end

  private

  def normalize_tags
    self.tags = tags.map(&:to_s).map(&:downcase).map(&:strip).uniq
  end

  def sync_to_knowledge_base
    # Knowledge Base에 동기화
    return unless approved?

    KnowledgeBase::QaPair.create!(
      question: question,
      answer: answer,
      source: "error_pattern_#{id}",
      metadata: to_qa_pair[:metadata]
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to sync pattern to knowledge base: #{e.message}"
  end

  def update_knowledge_base
    return unless approved?

    qa_pair = KnowledgeBase::QAPair.find_by(source: "error_pattern_#{id}")
    return unless qa_pair

    qa_pair.update!(
      question: question,
      answer: answer,
      metadata: to_qa_pair[:metadata]
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to update knowledge base: #{e.message}"
  end
end
