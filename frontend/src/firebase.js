import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';

const firebaseConfig = {
  apiKey: "AIzaSyArplPV6X4CIuEI1UKG0QXFVVj5aZUkoug",
  authDomain: "sevasync-e053b.firebaseapp.com",
  projectId: "sevasync-e053b",
  storageBucket: "sevasync-e053b.firebasestorage.app",
  messagingSenderId: "368000301814",
  appId: "1:368000301814:web:78694c0dace0c7937e4ad7",
  measurementId: "G-E00X9TM7TW"
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
