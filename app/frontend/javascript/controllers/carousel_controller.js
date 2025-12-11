import { Controller } from "@hotwired/stimulus"
import Swiper from "swiper"
import { Navigation, Pagination, Autoplay } from "swiper/modules"

export default class extends Controller {
  connect() {
    // Check if this is a multi-slide carousel (addon or related products)
    const isAddonCarousel = this.element.classList.contains('addon-carousel')
    const isRelatedProductsCarousel = this.element.classList.contains('related-products-carousel')
    const isMultiSlideCarousel = isAddonCarousel || isRelatedProductsCarousel

    // Count slides to determine if loop should be enabled
    const slideCount = this.element.querySelectorAll('.swiper-slide').length

    const config = {
      modules: [Navigation, Pagination, Autoplay],
      // Loop disabled: Swiper loop mode requires minimum 2x slidesPerView slides
      // With dynamic slide counts, this could cause visual duplication issues
      loop: false,
      pagination: {
        el: ".swiper-pagination",
        clickable: true,
      },
      navigation: {
        nextEl: ".bestsellers-button-next, .related-products-button-next, .swiper-button-next",
        prevEl: ".bestsellers-button-prev, .related-products-button-prev, .swiper-button-prev",
      },
      autoplay: slideCount > 1 ? {
        delay: 5000,
        disableOnInteraction: false,
        pauseOnMouseEnter: true,
      } : false, // Disable autoplay if only 1 slide
    }

    // Add responsive breakpoints for multi-slide carousels
    if (isMultiSlideCarousel) {
      config.slidesPerView = 2
      config.spaceBetween = 20
      config.breakpoints = {
        640: {
          slidesPerView: 2,
          spaceBetween: 20,
        },
        768: {
          slidesPerView: 3,
          spaceBetween: 20,
        },
        1024: {
          slidesPerView: 4,
          spaceBetween: 30,
        },
      }
    }

    this.swiper = new Swiper(this.element, config)
  }

  disconnect() {
    if (this.swiper) {
      this.swiper.destroy(true, true)
      this.swiper = null
    }
  }
} 