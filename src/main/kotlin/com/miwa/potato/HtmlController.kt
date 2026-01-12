package com.miwa.potato

import com.miwa.potato.domain.model.User
import com.miwa.potato.domain.repository.UserRepository
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.ui.set
import org.springframework.web.bind.annotation.GetMapping

@Controller
class HtmlController(
    private val userRepository: UserRepository
) {

    @GetMapping("/")
    fun blog(model: Model): String {
        val users = userRepository.findAll()
        model["title"] = "Potato Blog"
        model["user"] = users.first().name
        return "blog"
    }
}