require 'spec_helper'

describe Admin::ResearchThemesController do
  describe "GET new" do
    it_behaves_like "require sign in" do
      let(:action) { get :new }
    end
    it_behaves_like "require admin" do
      let(:action) { get :new }
    end

    it "sets the @ research_theme to a new research theme" do
      set_current_admin
      get :new
      expect(assigns(:research_theme)).to be_instance_of ResearchTheme
      expect(assigns(:research_theme)).to be_new_record
    end

    it "sets the flash error message for regular user" do
      set_current_user
      get :new
      expect(flash[:alert]).to be_present
    end
  end

  describe "POST create" do
    it_behaves_like "require sign in" do
      let(:action) { post :create }
    end

    it_behaves_like "require admin" do
      let(:action) { post :create }
    end

    context "with valid input" do
      it "redirects to the admin research themes page" do
        set_current_admin
        post :create, research_theme: { title: "theme 1", description: "description for theme 1" }
        expect(response).to redirect_to admin_research_themes_path
      end

      it "creates a new research theme" do
        set_current_admin
        post :create, research_theme: { title: "theme 1", description: "description for theme 1" }

        expect(ResearchTheme.count).to eq(1)
      end

      it "sets the flash success message" do
        set_current_admin
        post :create, research_theme: { title: "theme 1", description: "description for theme 1" }

        expect(flash[:notice]).to be_present
      end
    end

    context "with invalid input" do
      it "does not create a new research theme" do
        set_current_admin
        post :create, research_theme: { title: "", description: "description for theme 1" }
        expect(ResearchTheme.count).not_to eq(1)
      end

      it "renders the new template" do
        set_current_admin
        post :create, research_theme: { title: "", description: "description for theme 1" }
        expect(response).to render_template :new
      end

      it "sets the @ research_theme variable" do
        set_current_admin
        post :create, research_theme: { title: "", description: "description for theme 1" }
        expect(assigns(:research_theme)).to be_present
      end

      it "sets the flash alert message" do
        set_current_admin
        post :create, research_theme: { title: "", description: "description for theme 1" }
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "PATCH#update" do
    it_behaves_like "require sign in" do
      let(:action) { post :create }
    end

    it_behaves_like "require admin" do
      let(:action) { post :create }
    end

    context "with invalid input" do
      it "does not update an existing record" do
        set_current_admin
        @research_theme = Fabricate(:research_theme)

        patch :update, id: @research_theme.id, research_theme: { title: "" }
        @research_theme.reload
        expect(ResearchTheme.find(@research_theme.id).title).not_to eq("") 
      end

      it "renders the edit template" do
        set_current_admin
        @research_theme = Fabricate(:research_theme)

        patch :update, id: @research_theme.id, research_theme: { title: "" }

        expect(response).to render_template :edit
      end

      it "sets a flash error message" do
        set_current_admin
        @research_theme = Fabricate(:research_theme)

        patch :update, id: @research_theme.id, research_theme: { title: "" }

        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "DELETE #destroy" do
    it_behaves_like "require sign in" do
      let(:action) { post :create }
    end
    
    it_behaves_like "require admin" do
      let(:action) { post :create }
    end

    it "redirects to the admin researchers page" do
      set_current_admin
      @research_theme = Fabricate(:research_theme)

      delete :destroy, id: @research_theme.id

      expect(response).to redirect_to admin_research_themes_path
    end

    it "deletes the researcher" do
      set_current_admin
      @research_theme = Fabricate(:research_theme)

      delete :destroy, id: @research_theme.id

      expect(Researcher.count).to eq(0)
    end

    it "sets the flash message" do
      set_current_admin
      @research_theme = Fabricate(:research_theme)

      delete :destroy, id: @research_theme.id

      expect(flash[:notice]).to be_present
    end
  end
end