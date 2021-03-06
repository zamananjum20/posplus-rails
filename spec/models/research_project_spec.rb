require 'spec_helper'

describe ResearchProject do
  it "requires a title" do
    research_project = Fabricate(:research_project)

    research_project.title = ""

    expect(research_project.valid?).to be_false
  end

  it "requires a bodytext" do
    research_project = Fabricate(:research_project)

    research_project.body = ""

    expect(research_project.valid?).to be_false
  end
  
  it "should destroy research_theme dependency when destroyed" do
    research_project = Fabricate(:research_project)
    research_theme_1 = Fabricate(:research_theme)
    research_theme_2 = Fabricate(:research_theme)

    research_project.research_themes << research_theme_1
    research_project.research_themes << research_theme_2

    themes = research_project.research_themes

    research_project.destroy

    themes.each do |theme|
        theme.research_projects.should_not include(@research_project)
    end
  end
end
