# spec/domains/knowledge_base/repositories/qa_pair_repository_spec.rb
require 'rails_helper'

RSpec.describe KnowledgeBase::QaPairRepository do
  describe '.search_by_similarity' do
    let!(:qa_pair1) { create(:qa_pair, :with_embedding, question: "How to analyze Excel data?") }
    let!(:qa_pair2) { create(:qa_pair, :with_embedding, question: "What is data visualization?") }
    let!(:qa_pair3) { create(:qa_pair, :with_embedding, question: "How to create pivot tables?") }
    let!(:private_qa) { create(:qa_pair, :private, :with_embedding, question: "Private Excel analysis") }

    before do
      # Mock vector similarity search
      allow(KnowledgeBase::QaPair).to receive(:nearest_neighbors).and_return(
        KnowledgeBase::QaPair.where(id: [ qa_pair1.id, qa_pair3.id ])
      )
    end

    it 'returns similar QA pairs' do
      results = described_class.search_by_similarity("Excel analysis", limit: 5)

      expect(results).to include(qa_pair1, qa_pair3)
      expect(results).not_to include(qa_pair2)
    end

    it 'respects the limit parameter' do
      results = described_class.search_by_similarity("Excel", limit: 1)

      expect(results.count).to eq(1)
    end

    it 'excludes private QA pairs by default' do
      allow(KnowledgeBase::QaPair).to receive(:nearest_neighbors).and_return(
        KnowledgeBase::QaPair.where(id: [ qa_pair1.id, private_qa.id ])
      )

      results = described_class.search_by_similarity("Excel", limit: 5)

      expect(results).not_to include(private_qa)
    end

    it 'includes private QA pairs when include_private is true' do
      allow(KnowledgeBase::QaPair).to receive(:nearest_neighbors).and_return(
        KnowledgeBase::QaPair.where(id: [ qa_pair1.id, private_qa.id ])
      )

      results = described_class.search_by_similarity("Excel", limit: 5, include_private: true)

      expect(results).to include(private_qa)
    end
  end

  describe '.find_by_category' do
    let!(:general_qa1) { create(:qa_pair, category: 'general') }
    let!(:general_qa2) { create(:qa_pair, category: 'general') }
    let!(:technical_qa) { create(:qa_pair, category: 'technical') }

    it 'returns QA pairs for the specified category' do
      results = described_class.find_by_category('general')

      expect(results).to contain_exactly(general_qa1, general_qa2)
    end

    it 'returns empty array for non-existent category' do
      results = described_class.find_by_category('non_existent')

      expect(results).to be_empty
    end
  end

  describe '.find_by_source' do
    let(:excel_file) { create(:excel_file) }
    let!(:qa_from_excel) { create(:qa_pair, :from_excel_analysis, source_id: excel_file.id) }
    let!(:qa_manual) { create(:qa_pair) }

    it 'returns QA pairs from specified source' do
      results = described_class.find_by_source('excel_analysis', excel_file.id)

      expect(results).to contain_exactly(qa_from_excel)
    end
  end

  describe '.verified_only' do
    let!(:verified_qa1) { create(:qa_pair, :verified) }
    let!(:verified_qa2) { create(:qa_pair, :verified) }
    let!(:unverified_qa) { create(:qa_pair) }

    it 'returns only verified QA pairs' do
      results = described_class.verified_only

      expect(results).to contain_exactly(verified_qa1, verified_qa2)
    end
  end

  describe '.create_from_analysis' do
    let(:user) { create(:user) }
    let(:excel_file) { create(:excel_file, user: user) }
    let(:analysis_data) do
      {
        insights: [
          { question: "What is the total revenue?", answer: "The total revenue is $1.5M" },
          { question: "What is the growth rate?", answer: "The growth rate is 15% YoY" }
        ]
      }
    end

    it 'creates multiple QA pairs from analysis data' do
      expect {
        described_class.create_from_analysis(analysis_data, excel_file, user)
      }.to change(KnowledgeBase::QaPair, :count).by(2)
    end

    it 'associates QA pairs with the source' do
      results = described_class.create_from_analysis(analysis_data, excel_file, user)

      results.each do |qa_pair|
        expect(qa_pair.source_type).to eq('excel_analysis')
        expect(qa_pair.source_id).to eq(excel_file.id)
        expect(qa_pair.user).to eq(user)
      end
    end

    it 'handles errors gracefully' do
      invalid_data = { insights: nil }

      expect {
        described_class.create_from_analysis(invalid_data, excel_file, user)
      }.not_to raise_error
    end
  end

  describe '.update_embeddings' do
    let!(:qa_without_embedding) { create(:qa_pair, question_embedding: nil) }
    let!(:qa_with_embedding) { create(:qa_pair, :with_embedding) }

    before do
      allow_any_instance_of(KnowledgeBase::EmbeddingService).to receive(:generate_embedding)
        .and_return(Array.new(1536) { rand(-1.0..1.0) })
    end

    it 'generates embeddings for QA pairs without embeddings' do
      described_class.update_embeddings

      qa_without_embedding.reload
      expect(qa_without_embedding.question_embedding).to be_present
      expect(qa_without_embedding.question_embedding.length).to eq(1536)
    end

    it 'does not update existing embeddings' do
      original_embedding = qa_with_embedding.question_embedding

      described_class.update_embeddings

      qa_with_embedding.reload
      expect(qa_with_embedding.question_embedding).to eq(original_embedding)
    end
  end
end
