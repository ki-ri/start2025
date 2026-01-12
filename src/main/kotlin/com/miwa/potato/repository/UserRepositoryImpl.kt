package com.miwa.potato.repository

import com.miwa.potato.domain.model.User
import com.miwa.potato.domain.repository.UserRepository
import com.miwa.potato.generated.jooq.Tables.USERS
import com.miwa.potato.generated.jooq.tables.records.UsersRecord
import org.jooq.DSLContext
import org.springframework.stereotype.Repository

@Repository
class UserRepositoryImpl(
    private val context: DSLContext
): UserRepository {
    override fun findAll(): List<User> {
        return context.selectFrom(USERS)
            .toList()
            .map { it.toDomainModel() }
    }

    private fun UsersRecord.toDomainModel(): User {
        return User(
            id = this.id.toString(),
            name = this.name
        )
    }
}