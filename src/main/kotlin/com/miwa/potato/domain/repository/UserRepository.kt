package com.miwa.potato.domain.repository

import com.miwa.potato.domain.model.User

interface UserRepository {
    fun findAll(): List<User>
}