_ = require 'underscore'
benv = require 'benv'
sinon = require 'sinon'
Backbone = require 'backbone'
CurrentUser = require '../../../../models/current_user'
{ fabricate } = require 'antigravity'
{ resolve } = require 'path'
{ stubChildClasses } = require '../../../../test/helpers/stubs'

describe 'FavoritesView', ->

  beforeEach (done) ->
    benv.setup =>
      benv.expose { $: benv.require 'jquery' }
      Backbone.$ = $
      $.fn.hidehover = sinon.stub()
      $.fn.infiniteScroll  = sinon.stub()
      sinon.stub Backbone, 'sync'
      benv.render resolve(__dirname, '../fixtures/favorites.jade'), { sd: {} }, =>
        { FavoritesView } = mod = benv.requireWithJadeify(
          resolve(__dirname, '../../client/favorites')
          ['hintTemplate']
        )
        mod.__set__ 'mediator', @mediator = trigger: sinon.stub(), on: sinon.stub()
        CurrentUser = mod.__get__ 'CurrentUser'
        CurrentUser.orNull = -> new CurrentUser fabricate 'user'
        stubChildClasses mod, this,
          ['ArtworkColumnsView', 'SuggestedGenesView', 'ShareView']
          ['appendArtworks', 'render']
        @view = new FavoritesView el: $('body')
        done()

  afterEach ->
    benv.teardown()
    Backbone.sync.restore()

  describe '#initialize', ->

    it 'sets up an artwork columns view with the user favorites', ->
      (@ArtworkColumnsView.args[0][0].collection.fetchCollections?).should.be.ok

  describe '#setup', ->

    it 'fetches the user collections and shows an empty state if there are none', ->
      sinon.stub @view, 'showEmptyHint'
      @view.setup()
      _.last(Backbone.sync.args)[2].success []
      @view.showEmptyHint.called.should.be.ok

    it 'shows an empty state if there are no works in any collections', ->
      sinon.stub @view, 'showEmptyHint'
      @view.setup()
      _.last(Backbone.sync.args)[2].success [{ id: 'saved-artwork' }, { id: 'bathroom-warhols' }]
      for args in _.last(Backbone.sync.args, 2)
        args[2].success []
        args[2].complete []
      @view.showEmptyHint.called.should.be.ok

  describe '#showEmptyHint', ->

    it 'adds a SuggestedGenesView and removes infinite scroll', ->
      sinon.stub @view, 'endInfiniteScroll'
      @view.showEmptyHint()
      @view.endInfiniteScroll.called.should.be.ok
      @SuggestedGenesView.args[0][0].user.should.equal @view.user

  describe '#appendArtworks', ->

    it 'adds the collection of artworks to the columns view', ->
      @view.appendArtworks col = new Backbone.Collection [{ foo: 'bar' }]
      @view.artworkColumnsView.appendArtworks.args[0][0][0].get('foo').should.equal 'bar'


describe 'Favorites', ->

  beforeEach ->
    sinon.stub Backbone, 'sync'
    @user = new CurrentUser fabricate 'user'
    { Favorites } = require '../../client/favorites'
    @favorites = new Favorites [], user: @user

  afterEach ->
    Backbone.sync.restore()

  describe '#fetchCollections', ->

    it 'fetches the collections for that user and sets them', ->
      @favorites.fetchCollections()
      Backbone.sync.args[0][2].url.should.include 'api/v1/collections'
      Backbone.sync.args[0][2].success [{ id: 'saved-artwork' }]
      @favorites.collections.first().get('id').should.equal 'saved-artwork'

  describe '#fetchNextPage', ->

    it 'fetches each collections artworks in parallel and triggers a nextPage with that set', (done) ->
      @favorites.collections = new Backbone.Collection [{ id: 'saved-artwork' }, { id: 'bathroom-warhols' }]
      @favorites.fetchNextPage()
      @favorites.on 'nextPage', (artworks) ->
        artworks.at(0).get('id').should.equal 'foo0'
        artworks.at(1).get('id').should.equal 'foo1'
        done()
      for args, i in _.last(Backbone.sync.args, 2)
        args[2].success [{ id: 'foo' + i }]
        args[2].complete []
