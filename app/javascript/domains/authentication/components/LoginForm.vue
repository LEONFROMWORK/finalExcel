<template>
  <div class="min-h-screen flex items-center justify-center bg-black">
    <div class="w-full max-w-md">
      <!-- Logo/Title -->
      <div class="text-center mb-8">
        <h1 class="text-4xl font-bold text-white">Sign in</h1>
      </div>

      <!-- Login Form -->
      <Card class="bg-gray-900 border-gray-800">
        <template #content>
          <form @submit.prevent="handleLogin" class="p-2">
            <!-- Email Field -->
            <div class="mb-6">
              <label for="email" class="block text-gray-400 text-sm mb-2">Email</label>
              <InputText
                id="email"
                v-model="form.email"
                type="email"
                placeholder="Your email address"
                class="w-full bg-gray-800 border-gray-700 text-white placeholder-gray-500"
                :class="{ 'p-invalid': errors.email }"
                required
              />
              <small v-if="errors.email" class="p-error">{{ errors.email }}</small>
            </div>

            <!-- Password Field (if not OAuth) -->
            <div v-if="showPassword" class="mb-6">
              <label for="password" class="block text-gray-400 text-sm mb-2">Password</label>
              <Password
                id="password"
                v-model="form.password"
                placeholder="Your password"
                class="w-full"
                inputClass="w-full bg-gray-800 border-gray-700 text-white placeholder-gray-500"
                :feedback="false"
                :toggleMask="true"
                required
              />
              <small v-if="errors.password" class="p-error">{{ errors.password }}</small>
            </div>

            <!-- Continue Button -->
            <Button
              type="submit"
              label="Continue"
              class="w-full bg-orange-500 hover:bg-orange-600 border-orange-500"
              :loading="loading"
              :disabled="loading"
            />

            <!-- OR Divider -->
            <Divider align="center" class="my-6">
              <span class="text-gray-500 text-sm">OR</span>
            </Divider>

            <!-- Google OAuth -->
            <Button
              type="button"
              @click="handleGoogleLogin"
              class="w-full bg-gray-800 hover:bg-gray-700 border-gray-700"
              :disabled="loading"
            >
              <svg class="w-5 h-5 mr-2" viewBox="0 0 24 24">
                <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
                <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
                <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
                <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
              </svg>
              Continue with Google
            </Button>

            <!-- Sign Up Link -->
            <div class="text-center mt-6">
              <span class="text-gray-500">Don't have an account? </span>
              <router-link to="/signup" class="text-orange-500 hover:text-orange-400">
                Sign up
              </router-link>
            </div>
          </form>
        </template>
      </Card>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/authStore'
import Card from 'primevue/card'
import InputText from 'primevue/inputtext'
import Password from 'primevue/password'
import Button from 'primevue/button'
import Divider from 'primevue/divider'

const router = useRouter()
const authStore = useAuthStore()

const form = ref({
  email: '',
  password: ''
})

const showPassword = ref(false)
const loading = ref(false)
const errors = ref({})

const handleLogin = async () => {
  if (!showPassword.value && form.value.email) {
    // First step: check if user exists
    showPassword.value = true
    return
  }

  loading.value = true
  
  try {
    const result = await authStore.login({
      email: form.value.email,
      password: form.value.password
    })
    
    if (result.success) {
      router.push('/dashboard')
    }
  } catch (error) {
    console.error('Login failed:', error)
  } finally {
    loading.value = false
  }
}

const handleGoogleLogin = () => {
  window.location.href = '/api/v1/auth/google_oauth2'
}
</script>