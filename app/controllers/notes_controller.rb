class NotesController < ApplicationController
  respond_to :html
  before_filter :require_user, only: %i(create edit update delete rsvp publish_draft)

  def index
    @title = I18n.t('notes_controller.research_notes')
    set_sidebar
  end

  def tools
    redirect_to '/methods', status: 302
  end

  def places
    @title = 'Places'
    @notes = Node.joins('LEFT OUTER JOIN node_revisions ON node_revisions.nid = node.nid
                         LEFT OUTER JOIN community_tags ON community_tags.nid = node.nid
                         LEFT OUTER JOIN term_data ON term_data.tid = community_tags.tid')
      .select('*, max(node_revisions.timestamp)')
      .where(status: 1, type:%w(page place))
      .includes(:revision, :tag)
      .references(:term_data)
      .where('term_data.name = ?', 'chapter')
      .group('node.nid')
      .order('max(node_revisions.timestamp) DESC, node.nid')
      .paginate(page: params[:page], per_page: 24)

    render template: 'notes/tools_places'
  end

  def shortlink
    @node = Node.find params[:id]
    if @node.has_power_tag('question')
      redirect_to URI.parse(@node.path(:question)).path
    else
      redirect_to URI.parse(@node.path).path
    end
  end

  # display a revision, raw
  def raw
    response.headers['Content-Type'] = 'text/plain; charset=utf-8'
    render text: Node.find(params[:id]).latest.body
  end

  def show
    if params[:author] && params[:date]
      @node = Node.find_notes(params[:author], params[:date], params[:id])
      @node ||= Node.where(path: "/report/#{params[:id]}").first
    else
      @node = Node.find params[:id]
    end

    if @node.status == 3 && current_user.nil?
      flash[:warning] = "You need to login to view the page"
      redirect_to '/login'
      return
    elsif @node.status == 3 && @node.author.user != current_user && !current_user.can_moderate? && !@node.has_tag("with:#{current_user.username}")
      flash[:notice] = "Only author can access the draft note"
      redirect_to '/'
      return
    end

    if @node.has_power_tag('question')
      redirect_to @node.path(:question)
      return
    end

    if @node.has_power_tag('redirect')
      if current_user.nil? || !current_user.can_moderate?
        redirect_to URI.parse(Node.find(@node.power_tag('redirect')).path).path
        return
      elsif current_user.can_moderate?
        flash.now[:warning] = "Only moderators and admins see this page, as it is redirected to #{Node.find(@node.power_tag('redirect')).title}.
        To remove the redirect, delete the tag beginning with 'redirect:'"
      end
    end

    return if check_and_redirect_node(@node)

    alert_and_redirect_moderated

    impressionist(@node, 'show', unique: [:ip_address])
    @title = @node.latest.title
    @tags = @node.tags
    @tagnames = @tags.collect(&:name)

    set_sidebar :tags, @tagnames
  end

  def image
    params[:size] = params[:size] || :large
    node = Node.find(params[:id])
    if node.main_image
      redirect_to URI.parse(node.main_image.path(params[:size])).path
    else
      redirect_to 'data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw=='
    end
  end

  def create
    if current_user.drupal_user.status == 1
      saved, @node, @revision = Node.new_note(uid: current_user.uid,
                                              title: params[:title],
                                              body: params[:body],
                                              main_image: params[:main_image])

      if params[:draft] == "true" && current_user.first_time_poster
        flash[:notice] = "First-time users are not eligible to create a draft."
        redirect_to '/'
        return
      elsif params[:draft] == "true"
         @node.draft
      end

      if saved
        params[:tags]&.tr(' ', ',').split(',').each do |tagname|
            @node.add_tag(tagname.strip, current_user)
        end
        if params[:event] == 'on'
          @node.add_tag('event', current_user)
          @node.add_tag('event:rsvp', current_user)
          @node.add_tag('date:' + params[:date], current_user) if params[:date]
        end
        if params[:draft] != "true"
          if current_user.first_time_poster
            flash[:first_time_post] = true
            if @node.has_power_tag('question')
              flash[:notice] = I18n.t('notes_controller.thank_you_for_question').html_safe
            else
              flash[:notice] = I18n.t('notes_controller.thank_you_for_contribution').html_safe
            end
          else
            if @node.has_power_tag('question')
              flash[:notice] = I18n.t('notes_controller.question_note_published').html_safe
            else
              flash[:notice] = I18n.t('notes_controller.research_note_published').html_safe
            end
          end
        else
          flash[:notice] = I18n.t('notes_controller.saved_as_draft').html_safe
        end
        # Notice: Temporary redirect.Remove this condition after questions show page is complete.
        #         Just keep @node.path(:question)
        if params[:redirect] && params[:redirect] == 'question'
          redirect_to @node.path(:question)
        else
          if request.xhr? # rich editor!
            render text: @node.path
          else
            redirect_to @node.path
          end
        end
      else
        if request.xhr? # rich editor!
          errors = @node.errors
          errors = errors.to_hash.merge(@revision.errors.to_hash) if @revision&.errors
          render json: errors
        else
          render template: 'editor/post'
        end
      end
    else
      flash.keep[:error] = I18n.t('notes_controller.you_have_been_banned').html_safe
      redirect_to '/logout'
    end
  end

  def edit
    @node = Node.find_by(nid: params[:id], type: 'note')
    if current_user.uid == @node.uid || current_user.admin? || @node.has_tag("with:#{current_user.username}")
      if params[:legacy]
        render template: 'editor/post'
      else
        if @node.main_image
          @main_image = @node.main_image.path(:default)
        elsif params[:main_image] && Image.find_by(id: params[:main_image])
          @main_image = Image.find_by(id: params[:main_image]).path
        elsif @image
          @main_image = @image.path(:default)
        end
        flash.now[:notice] = "This is the new rich editor. For the legacy editor, <a href='/notes/edit/#{@node.id}?#{request.env['QUERY_STRING']}&legacy=true'>click here</a>."
        render template: 'editor/rich'
      end
    else
      if @node.has_power_tag('question')
        prompt_login I18n.t('notes_controller.author_can_edit_question')
      else
        prompt_login I18n.t('notes_controller.author_can_edit_note')
      end
    end
  end

  # at /notes/update/:id
  def update
    @node = Node.find(params[:id])
    if current_user.uid == @node.uid || current_user.admin? || @node.has_tag("with:#{current_user.username}")
      @revision = @node.latest
      @revision.title = params[:title]
      @revision.body = params[:body]
      @revision.timestamp = Time.now.to_i
      if params[:tags]
        params[:tags]&.tr(' ', ',')&.split(',')&.each do |tagname|
          @node.add_tag(tagname, current_user)
        end
      end
      if @revision.valid?
        @revision.save
        @node.vid = @revision.vid
        # update vid (version id) of main image
        if @node.drupal_main_image
          i = @node.drupal_main_image
          i.vid = @revision.vid
          i.save
        end
        @node.drupal_content_field_image_gallery.each do |img|
          img.vid = @revision.vid
          img.save
        end
        @node.title = @revision.title
        # save main image
        if params[:main_image] && params[:main_image] != ''
          img = Image.find params[:main_image]
          unless img.nil?
            img.nid = @node.id
            @node.main_image_id = img.id
            img.save
          end
        end
        @node.save!
        flash[:notice] = I18n.t('notes_controller.edits_saved')
        format = false
        format = :question if params[:redirect] && params[:redirect] == 'question'
        if request.xhr?
          render text: "#{@node.path(format).to_s}?_=#{Time.now.to_i}"
        else
          redirect_to URI.parse(@node.path(format)).path + '?_=' + Time.now.to_i.to_s
        end
      else
        flash[:error] = I18n.t('notes_controller.edit_not_saved')
        if request.xhr? || params[:rich]
          errors = @node.errors
          errors = errors.to_hash.merge(@revision.errors.to_hash) if @revision&.errors
          render json: errors
        else
          render 'editor/post'
       end
      end
    end
  end

  # at /notes/delete/:id
  # only for notes
  def delete
    @node = Node.find(params[:id])
    if current_user && (current_user.uid == @node.uid || current_user.can_moderate?)
      if @node.authors.uniq.length == 1
        @node.destroy
        respond_with do |format|
          format.html do
            if request.xhr?
              render text: I18n.t('notes_controller.content_deleted')
            else
              flash[:notice] = I18n.t('notes_controller.content_deleted')
              redirect_to '/dashboard' + '?_=' + Time.now.to_i.to_s
            end
          end
      end
    else
      flash[:error] = I18n.t('notes_controller.more_than_one_contributor')
      redirect_to '/dashboard' + '?_=' + Time.now.to_i.to_s
    end
    else
      prompt_login
    end
  end

  # notes for a given author
  def author
    @user = DrupalUser.find_by(name: params[:id])
    @title = @user.name
    @notes = Node.paginate(page: params[:page], per_page: 24)
      .order('nid DESC')
      .where(type: 'note', status: 1, uid: @user.uid)
    render template: 'notes/index'
  end

  # notes for given comma-delimited tags params[:topic] for author
  def author_topic
    @user = DrupalUser.find_by(name: params[:author])
    @tagnames = params[:topic].split('+')
    @title = @user.name + " on '" + @tagnames.join(', ') + "'"
    @notes = @user.notes_for_tags(@tagnames)
    @unpaginated = true
    render template: 'notes/index'
  end

  # notes with high # of likes
  def liked
    @title = I18n.t('notes_controller.highly_liked_research_notes')
    @wikis = Node.limit(10)
      .where(type: 'page', status: 1)
      .order('nid DESC')

    @notes = Node.research_notes
      .where(status: 1)
      .limit(20)
      .order('nid DESC')
    @unpaginated = true
    render template: 'notes/index'
  end

  def recent
    @title = I18n.t('notes_controller.recent_research_notes')
    @wikis = Node.limit(10)
      .where(type: 'page', status: 1)
      .order('nid DESC')
    @notes = Node.where(type: 'note', status: 1, created: Time.now.to_i - 1.weeks.to_i..Time.now.to_i)
    @unpaginated = true
    render template: 'notes/index'
  end

  # notes with high # of views
  def popular
    @title = I18n.t('notes_controller.popular_research_notes')
    @wikis = Node.limit(10)
      .where(type: 'page', status: 1)
      .order('nid DESC')
    @notes = Node.research_notes
      .limit(20)
      .where(status: 1)
      .order('views DESC')
    @unpaginated = true
    render template: 'notes/index'
  end

  def rss
    limit = 20
    if params[:moderators]
      @notes = Node.limit(limit)
        .order('nid DESC')
        .where('type = ? AND status = 4', 'note')
    else
      @notes = Node.limit(limit)
        .order('nid DESC')
        .where('type = ? AND status = 1', 'note')
    end
    respond_to do |format|
      format.rss do
        render layout: false
        response.headers['Content-Type'] = 'application/xml; charset=utf-8'
        response.headers['Access-Control-Allow-Origin'] = '*'
      end
    end
  end

  def liked_rss
    @notes = Node.limit(20)
      .order('created DESC')
      .where('type = ? AND status = 1 AND cached_likes > 0', 'note')
    respond_to do |format|
      format.rss do
        render layout: false, template: 'notes/rss'
        response.headers['Content-Type'] = 'application/xml; charset=utf-8'
      end
    end
  end

  def rsvp
    @node = Node.find params[:id]
    # leave a comment
    @comment = @node.add_comment(subject: 'rsvp', uid: current_user.uid, body: 'I will be attending!')
    # make a tag
    @node.add_tag('rsvp:' + current_user.username, current_user)
    redirect_to URI.parse(@node.path).path + '#comments'
  end

  # Updates title of a wiki page, takes id and title as query string params. maps to '/node/update/title'
  def update_title
    node = Node.find params[:id].to_i
    unless current_user && current_user.drupal_user == node.author
      flash.keep[:error] = I18n.t('notes_controller.author_can_edit_note')
      return redirect_to URI.parse(node.path).path + "#comments"
    end
    node.update(title: params[:title])
    redirect_to URI.parse(node.path).path + "#comments"
  end

  def publish_draft
    @node = Node.find(params[:id])
    if current_user && current_user.uid == @node.uid || current_user.can_moderate? || @node.has_tag("with:#{current_user.username}")
      @node.path = @node.generate_path
      @node.publish
      SubscriptionMailer.notify_node_creation(@node).deliver_now
      flash[:notice] = "Thanks for your contribution. Research note published! Now, it's visible publically."
      redirect_to @node.path
    else
      flash[:warning] = "You are not author or moderator so you can't publish a draft!"
      redirect_to '/'
    end
  end
end