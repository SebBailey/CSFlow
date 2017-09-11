class exports.CSFlow extends Layer
		
	constructor: (options={}) ->
		options.width ?= Screen.width
		options.height ?= Screen.height
		options.clip ?= true
		options.initialViewName ?= 'initialView'
		options.backButtonName ?= 'backButton'
		options.animationOptions ?= { curve: "cubic-bezier(0.19, 1, 0.22, 1)", time: .7 }
		options.backgroundColor ?= "#222"
		options.scroll ?= true
		options.autoLink ?= true

		super options
		@history = []

		previousStart = 0; previousBrightness = 0; start = 0; current = 0; diff = 0; maxDiff = 200
		@on Events.SwipeRightStart, (event) ->
			if @history.length > 1
				previousStart = -@width/5
				previousBrightness = @history[0].view.brightness

		@on Events.SwipeRight, (event) ->
			start = event.start.x
			current = event.touchCenter.x
			diff = current - start
			if @history.length > 1
				@history[0].view.props =
					x: Utils.modulate diff, [30, maxDiff], [previousStart, 0], true
					# brightness: Utils.modulate diff, [30, maxDiff], [previousBrightness, 100], true
				@currentView.x = diff - 30

		@on Events.SwipeRightEnd, (event) ->
			if @history.length > 1
				if diff >= maxDiff
					@pushOutRight @history[0].view, true
				else
					@currentView.animate
						x: 0
						options:
							curve: "ease"
					@history[0].view.animate
						x: previousStart
						brightness: previousBrightness

		@onChange "subLayers", (changeList) =>
			view = changeList.added[0]
			if view?
				# default behaviors for views
				view.clip = true
				view.on Events.Click, -> return # prevent click-through/bubbling
				# add scrollcomponent
				if @scroll && (view.width > @.width || view.height > @.height)
					children = view.children
					scrollComponent = new ScrollComponent
						name: "scrollComponent"
						width: @width
						height: @height
						parent: view
						contentInset:
							bottom: 50
					scrollComponent.content.backgroundColor = ""
					if view.width <= @width
						scrollComponent.scrollHorizontal = false
					if view.height <= @height
						scrollComponent.scrollVertical = false
					for c in children
						c.parent = scrollComponent.content
					view.scrollComponent = scrollComponent # make it accessible as a property
					# reset size since content moved to scrollComponent. prevents scroll bug when dragging outside.
					view.size = {width: @width, height: @height}

		transitions =
			switchInstant: {}
			fadeIn:
				newView:
					from: {opacity: 0}
					to: {opacity: 1}
			zoomIn:
				newView:
					from: {scale: 0.8, opacity: 0}
					to: {scale: 1, opacity: 1}
			zoomOut:
				oldView:
					to: {scale: 0.8, opacity: 0}
				newView:
					to: {}
			slideInUp:
				newView:
					from: {y: @height}
					to: {y: 0}
			slideInRight:
				newView:
					from: {x: @width}
					to: {x: 0}
			slideInDown:
				newView:
					from: {maxY: 0}
					to: {y: 0}
			moveInRight:
				oldView:
					to: {maxX: 0}
				newView:
					from: {x: @width}
					to: {x: 0}
			moveInLeft:
				oldView:
					to: {x: @width}
				newView:
					from: {maxX: 0}
					to: {x: 0}
			slideInLeft:
				newView:
					from: {maxX: 0}
					to: {maxX: @width}
			pushInRight:
				oldView:
					to: {x: -(@width/5), brightness: 70}
				newView:
					from: {x: @width}
					to: {x: 0}
			pushInLeft:
				oldView:
					to: {x: @width/5, brightness: 70}
				newView:
					from: {x: -@width}
					to: {x: 0}
			fadeOut:
				oldView:
					from: {opacity: 1}
					to: {opacity: 0}
			pushOutRight:
				oldView:
					to: {x: @width}
				newView:
					from: {x: -(@width/5), brightness: 70}
					to: {x: 0, brightness: 100}
			pushOutLeft:
				oldView:
					to: {maxX: 0}
				newView:
					from: {x: @width/5, brightness: 70}
					to: {x: 0, brightness: 100}
			slideOutUp:
				oldView:
					to: {maxY: 0}
				newView:
					to: {}
			slideOutRight:
				oldView:
					to: {x: @width}
				newView:
					to: {}
			slideOutDown:
				oldView:
					to: {y: @height}
				newView:
					to: {}
			slideOutLeft:
				oldView:
					to: {maxX: 0}
				newView:
					to: {}
			showModalBottom:
				newView:
					from: {y: Screen.height, x: 0, backgroundColor: null}
					to: {maxY: Screen.height}
				oldView:
					to: {brightness: 40}
			showModalTop:
				newView:
					from: {maxY: 0, x: 0, backgroundColor: null}
					to: {y: 0}
				oldView:
					to: {brightness: 40}
			showModalLeft:
				newView:
					from: {maxX: 0, y: 0, backgroundColor: null}
					to: {x: 0}
				oldView:
					to: {brightness: 40}
			showModalRight:
				newView:
					from: {x: Screen.width, y: 0, backgroundColor: null}
					to: {maxX: Screen.width}
				oldView:
					to: {brightness: 40}
			showModalCenter:
				newView:
					from: {midX: Screen.width/2, midY: Screen.height/2, opacity: 0, scale: 0.9, backgroundColor: null}
					to: {opacity: 1, scale: 1}
				oldView:
					to: {brightness: 40}



		# shortcuts
		transitions.slideIn = transitions.slideInRight
		transitions.slideOut = transitions.slideOutRight
		transitions.pushIn = transitions.pushInRight
		transitions.pushOut = transitions.pushOutRight

		# events
		Events.ViewWillSwitch = "viewWillSwitch"
		Events.ViewDidSwitch = "viewDidSwitch"
		Layer::onViewWillSwitch = (cb) -> @on(Events.ViewWillSwitch, cb)
		Layer::onViewDidSwitch = (cb) -> @on(Events.ViewDidSwitch, cb)		

		_.each transitions, (animProps, name) =>

			if options.autoLink
				layers = Framer.CurrentContext._layers
				for btn in layers
					if _.includes btn.name, name
						viewController = @
						btn.onClick ->
							sections = @name.split('_')
							anims = sections.slice(0, sections.length-1)
							linkName = sections[sections.length-1]
							linkName = linkName.replace('_', '')
							linkName = linkName.replace(/\d+/g, '') # remove numbers

							includesBackButton = _.find(anims, (anim) -> anim == options.backButtonName + '_' || anim == options.backButtonName)
							
							if includesBackButton?
								viewController.back()

							for anim, i in anims
								anim = anim.replace('_', '')
								if options.backButtonName?
									isBack = anim.replace('_', '') == options.backButtonName
								if !isBack
									viewController[anim] _.find(layers, (l) -> l.name is linkName)

			@[name] = (newView, overridePos, animationOptions = @animationOptions) =>

				return if newView is @currentView


				# make sure the new layer is inside the viewcontroller
				newView.parent = @
				newView.sendToBack()

				# reset props in case they were changed by a prev animation
				newView.point = {x:0, y: 0}
				newView.opacity = 1
				newView.scale = 1
				newView.brightness = 100
				
				# oldView
				if !overridePos
					@currentView?.point = {x: 0, y: 0} # fixes offset issue when moving too fast between screens
				@currentView?.props = animProps.oldView?.from
				animObj = _.extend {properties: animProps.oldView?.to}, animationOptions
				_.defaults(animObj, { properties: {} })
				outgoing = @currentView?.animate animObj

				# newView
				newView.props = animProps.newView?.from
				incoming = newView.animate _.extend {properties: animProps.newView?.to}, animationOptions
				
				# layer order
				if _.includes name, 'Out'
					newView.placeBehind(@currentView)
					outgoing.on Events.AnimationEnd, => @currentView.bringToFront()
				else
					newView.placeBefore(@currentView)
					
				@emit(Events.ViewWillSwitch, @currentView, newView)
				
				# change CurrentView before animation has finished so one could go back in history
				# without having to wait for the transition to finish
				@saveCurrentViewToHistory name, outgoing, incoming
				@currentView = newView
				@emit("change:previousView", @previousView)
				@emit("change:currentView", @currentView)
				
				if incoming.isAnimating
					hook = incoming 
				else
					hook = outgoing
				hook?.on Events.AnimationEnd, =>
					@emit(Events.ViewDidSwitch, @previousView, @currentView)
				

		if options.initialViewName?
			autoInitial = _.find Framer.CurrentContext._layers, (l) -> l.name is options.initialViewName
			if autoInitial? then @switchInstant autoInitial

		if options.initialView?
			@switchInstant options.initialView

		if options.backButtonName?
			backButtons = _.filter Framer.CurrentContext._layers, (l) -> l.name.replace(/\d+/g, '') is options.backButtonName
			for btn in backButtons
				btn.onClick => @back()

	@define "previousView",
			get: -> @history[0].view

	saveCurrentViewToHistory: (name,outgoingAnimation,incomingAnimation) ->
		@history.unshift
			view: @currentView
			animationName: name
			incomingAnimation: incomingAnimation
			outgoingAnimation: outgoingAnimation

	back: ->
		previous = @history[0]
		if previous.view?

			if _.includes previous.animationName, 'Out'
				previous.view.bringToFront()

			backIn = previous.outgoingAnimation.reverse()
			moveOut = previous.incomingAnimation.reverse()

			backIn.start()
			moveOut.start()

			@currentView = previous.view
			@history.shift()
			moveOut.on Events.AnimationEnd, => @currentView.bringToFront()
