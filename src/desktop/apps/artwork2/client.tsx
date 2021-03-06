import { buildClientApp } from "reaction/Artsy/Router/client"
import { routes } from "reaction/Apps/Artwork/routes"
import { data as sd } from "sharify"
import React from "react"
import ReactDOM from "react-dom"
import { enableIntercom } from "lib/intercom"

const $ = require("jquery")

const mediator = require("desktop/lib/mediator.coffee")
const User = require("desktop/models/user.coffee")
const Artwork = require("desktop/models/artwork.coffee")
const ArtworkInquiry = require("desktop/models/artwork_inquiry.coffee")
const openInquiryQuestionnaireFor = require("desktop/components/inquiry_questionnaire/index.coffee")
const openAuctionBuyerPremium = require("desktop/apps/artwork/components/auction/components/buyers_premium/index.coffee")
const ViewInRoomView = require("desktop/components/view_in_room/view.coffee")

buildClientApp({
  routes,
  context: {
    user: sd.CURRENT_USER,
    mediator,
  },
})
  .then(({ ClientApp }) => {
    ReactDOM.hydrate(<ClientApp />, document.getElementById("react-root"))
  })
  .catch(error => {
    console.error(error)
  })

if (module.hot) {
  module.hot.accept()
}

const openInquireableModal = (artworkId: string, { ask_specialist }) => {
  if (!artworkId) return
  const user = User.instantiate()
  const inquiry = new ArtworkInquiry({ notification_delay: 600 })
  const artwork = new Artwork({ id: artworkId })

  artwork.fetch().then(() => {
    openInquiryQuestionnaireFor({
      user,
      artwork,
      inquiry,
      ask_specialist,
    })
  })
}

mediator.on("launchInquiryFlow", options => {
  openInquireableModal(options.artworkId, { ask_specialist: false })
})

mediator.on("openBuyNowAskSpecialistModal", options => {
  openInquireableModal(options.artworkId, { ask_specialist: true })
})

mediator.on("openAuctionAskSpecialistModal", options => {
  const artworkId = options.artworkId
  if (artworkId) {
    const user = User.instantiate()
    const inquiry = new ArtworkInquiry({ notification_delay: 600 })
    const artwork = new Artwork({ id: artworkId })

    artwork.fetch().then(() => {
      artwork.set("is_in_auction", true)
      openInquiryQuestionnaireFor({
        user,
        artwork,
        inquiry,
        ask_specialist: true,
      })
    })
  }
})

mediator.on("openViewInRoom", options => {
  try {
    const { dimensions } = options
    const { url, width, height } = options.image

    let newWidth = width
    let newHeight = height

    const bounds = document
      .querySelector("[data-type=artwork-image]")
      .getBoundingClientRect()

    if (width > height) {
      newWidth = bounds.width
      newHeight = height * newWidth / width
    } else if (height > width) {
      newHeight = bounds.height
      newWidth = newHeight * width / height
    } else {
      newWidth = bounds.width
      newHeight = newWidth
    }

    const positionStyles = {
      position: "absolute",
      top: `${bounds.top + Math.abs(bounds.height - newHeight) / 2}px`,
      left: `${bounds.left}px`,
      width: `${newWidth}px`,
      height: `${newHeight}px`,
    }

    const viewInRoom = new ViewInRoomView({
      imgSelector: "[data-type=artwork-image]",
      imgUrl: url,
      positionStyles: positionStyles,
      dimensions: dimensions.cm,
    })

    $("body").prepend(viewInRoom.render().$el)
  } catch {
    // TODO: Add some proper error handling
  }
})

mediator.on("openAuctionBuyerPremium", options => {
  openAuctionBuyerPremium(options.auctionId)
})

mediator.on("enableIntercomForBuyers", options => {
  enableIntercom(options)
})
